defmodule RazorpayEx.RequestHttpTest do
  @moduledoc """
  End-to-end tests for the HTTP transport used by `RazorpayEx.Request`.

  Unlike the rest of the suite, these tests do not mock the HTTP client: they
  run against a real server started by `Bypass`, so they exercise the actual
  HTTPoison/hackney request path (query parameters, request bodies, timeouts
  and error mapping).
  """

  use ExUnit.Case, async: false

  @config_keys [
    :api_base_url,
    :auth_type,
    :key_id,
    :key_secret,
    :access_token,
    :custom_headers,
    :timeout
  ]

  setup do
    bypass = Bypass.open()
    previous = Map.new(@config_keys, &{&1, Application.fetch_env(:razorpay_ex, &1)})

    Application.put_env(:razorpay_ex, :api_base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:razorpay_ex, :auth_type, :basic)
    Application.put_env(:razorpay_ex, :key_id, "rzp_test_key")
    Application.put_env(:razorpay_ex, :key_secret, "test_secret")
    Application.put_env(:razorpay_ex, :timeout, 5_000)
    Application.delete_env(:razorpay_ex, :access_token)
    Application.delete_env(:razorpay_ex, :custom_headers)

    # The suite installs a Mox mock for the client; these tests exercise the
    # real HTTPoison/hackney transport instead.
    previous_client = Application.fetch_env(:razorpay_ex, :http_client)
    Application.put_env(:razorpay_ex, :http_client, RazorpayEx.HttpAdapter)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:razorpay_ex, key, value)
        {key, :error} -> Application.delete_env(:razorpay_ex, key)
      end)

      case previous_client do
        {:ok, client} -> Application.put_env(:razorpay_ex, :http_client, client)
        :error -> Application.delete_env(:razorpay_ex, :http_client)
      end
    end)

    %{bypass: bypass}
  end

  test "sends query parameters and auth headers on GET", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/payments", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      body =
        Jason.encode!(%{
          "query" => conn.query_params,
          "authorization" => Plug.Conn.get_req_header(conn, "authorization"),
          "user_agent" => Plug.Conn.get_req_header(conn, "user-agent")
        })

      Plug.Conn.send_resp(conn, 200, body)
    end)

    assert {:ok, %{status_code: 200, body: body}} =
             RazorpayEx.Request.raw_request(:get, "/v1/payments", %{}, params: %{count: 10})

    assert %{"query" => %{"count" => "10"}} = Jason.decode!(body)

    assert %{"authorization" => ["Basic " <> encoded], "user_agent" => ["razorpay_ex/" <> _]} =
             Jason.decode!(body)

    assert Base.decode64!(encoded) == "rzp_test_key:test_secret"
  end

  test "sends a JSON body on POST", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/orders", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      response =
        Jason.encode!(%{
          "body" => Jason.decode!(body),
          "content_type" => Plug.Conn.get_req_header(conn, "content-type")
        })

      Plug.Conn.send_resp(conn, 201, response)
    end)

    assert {:ok, %{status_code: 201, body: body}} =
             RazorpayEx.Request.raw_request(:post, "/v1/orders", %{
               "amount" => 50_000,
               "currency" => "INR"
             })

    assert %{
             "body" => %{"amount" => 50_000, "currency" => "INR"},
             "content_type" => ["application/json"]
           } = Jason.decode!(body)
  end

  test "maps API error responses to RazorpayEx.Error", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/payments/pay_bad", fn conn ->
      Plug.Conn.send_resp(
        conn,
        400,
        Jason.encode!(%{
          "error" => %{
            "code" => "BAD_REQUEST_ERROR",
            "description" => "Invalid payment id"
          }
        })
      )
    end)

    assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST_ERROR", http_status_code: 400}} =
             RazorpayEx.Request.request(:get, "/v1/payments/pay_bad")
  end

  test "returns a network error when the connection is refused" do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)

    Application.put_env(:razorpay_ex, :api_base_url, "http://127.0.0.1:#{port}")

    assert {:error, %RazorpayEx.Error{code: "NETWORK_ERROR"}} =
             RazorpayEx.Request.raw_request(:get, "/v1/payments")
  end

  test "enforces the configured timeout on a slow response" do
    # A server that accepts the connection but never sends a response.
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, ip: {127, 0, 0, 1}, active: false, reuseaddr: true])

    on_exit(fn -> :gen_tcp.close(listen_socket) end)

    {:ok, port} = :inet.port(listen_socket)

    server =
      spawn(fn ->
        case :gen_tcp.accept(listen_socket) do
          {:ok, socket} ->
            Process.sleep(3_000)
            :gen_tcp.close(socket)

          {:error, _reason} ->
            :ok
        end
      end)

    Application.put_env(:razorpay_ex, :api_base_url, "http://127.0.0.1:#{port}")
    Application.put_env(:razorpay_ex, :timeout, 150)

    started = System.monotonic_time(:millisecond)
    result = RazorpayEx.Request.raw_request(:get, "/v1/payments")
    elapsed = System.monotonic_time(:millisecond) - started

    assert {:error, %RazorpayEx.Error{code: "NETWORK_ERROR"}} = result
    assert elapsed < 1_500, "request was not bounded by the configured timeout (#{elapsed}ms)"

    Process.exit(server, :kill)
  end

  test "list endpoints return entities end to end", %{bypass: bypass} do
    body =
      Jason.encode!(%{
        "entity" => "collection",
        "count" => 2,
        "items" => [
          %{
            "entity" => "payment",
            "id" => "pay_1",
            "amount" => 100,
            "acquirer_data" => %{"rrn" => "1"}
          },
          %{"entity" => "payment", "id" => "pay_2", "amount" => 200}
        ]
      })

    Bypass.expect_once(bypass, "GET", "/payments", fn conn ->
      Plug.Conn.send_resp(conn, 200, body)
    end)

    assert {:ok, [first, second]} = RazorpayEx.Payment.all(%{count: 2})
    assert %RazorpayEx.Payment{id: "pay_1", amount: 100} = first
    assert first.extra == %{"acquirer_data" => %{"rrn" => "1"}}
    assert %RazorpayEx.Payment{id: "pay_2", amount: 200} = second
  end
end
