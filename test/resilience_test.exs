defmodule RazorpayEx.ResilienceTest do
  @moduledoc """
  Retries, request logging and pagination.
  """

  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Mox

  alias RazorpayEx.{Client, Paginator, Payment, Refund}

  setup :verify_on_exit!

  setup do
    previous =
      Map.new(
        [
          :api_base_url,
          :key_id,
          :key_secret,
          :auth_type,
          :custom_headers,
          :enable_logging,
          :timeout
        ],
        &{&1, Application.fetch_env(:razorpay_ex, &1)}
      )

    Application.put_env(:razorpay_ex, :auth_type, :basic)
    Application.put_env(:razorpay_ex, :key_id, "test_key_id")
    Application.put_env(:razorpay_ex, :key_secret, "test_key_secret")
    Application.put_env(:razorpay_ex, :api_base_url, "https://api.razorpay.com/v1")
    Application.put_env(:razorpay_ex, :enable_logging, false)
    Application.delete_env(:razorpay_ex, :custom_headers)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:razorpay_ex, key, value)
        {key, :error} -> Application.delete_env(:razorpay_ex, key)
      end)
    end)

    :ok
  end

  defp sequence(responses) do
    {:ok, agent} = Agent.start_link(fn -> responses end)

    expect(RazorpayEx.HttpClientMock, :request, length(responses), fn _method,
                                                                      _url,
                                                                      _body,
                                                                      _headers,
                                                                      _opts ->
      Agent.get_and_update(agent, fn [next | rest] -> {next, rest} end)
    end)
  end

  defp ok(body, status \\ 200), do: {:ok, %{status_code: status, body: body, headers: []}}

  defp page(count, from) do
    items =
      for i <- from..(from + count - 1) do
        ~s({"entity":"payment","id":"pay_#{i}","amount":#{i}})
      end

    ~s({"entity":"collection","count":#{count},"items":[#{Enum.join(items, ",")}]})
  end

  describe "retries" do
    test "retries a 5xx when asked to" do
      sequence([ok("{", 500), ok("[]")])

      assert {:ok, []} = Client.request(:get, "/payments", %{}, retry: 1, retry_delay: 0)
    end

    test "does not retry by default" do
      sequence([ok("{}", 500)])
      assert {:error, %{code: "HTTP_500"}} = Client.request(:get, "/payments")
    end

    test "gives up after the configured number of retries" do
      sequence([ok("{}", 503), ok("{}", 503), ok("{}", 503)])

      assert {:error, %{code: "HTTP_503"}} =
               Client.request(:get, "/payments", %{}, retry: 2, retry_delay: 0)
    end

    test "retries a transport error and succeeds" do
      sequence([{:error, %{reason: :econnrefused}}, ok("[]")])

      assert {:ok, []} = Client.request(:get, "/payments", %{}, retry: 1, retry_delay: 0)
    end

    test "returns a network error when retries are exhausted" do
      sequence([{:error, %{reason: :econnrefused}}, {:error, %{reason: :econnrefused}}])

      assert {:error, %{code: "NETWORK_ERROR"}} =
               Client.request(:get, "/payments", %{}, retry: 1, retry_delay: 0)
    end

    test "retries 409 Conflict (a request that is still being processed)" do
      sequence([ok("{}", 409), ok("[]")])

      assert {:ok, []} =
               Client.request(:post, "/payments/pay_1/capture", %{}, retry: 1, retry_delay: 0)
    end

    test "does not retry client errors" do
      sequence([ok(~s({"error":{"code":"BAD_REQUEST_ERROR"}}), 400)])

      assert {:error, %{code: "BAD_REQUEST_ERROR"}} =
               Client.request(:get, "/payments", %{}, retry: 3, retry_delay: 0)
    end
  end

  describe "request logging" do
    test "logs method, path and status but never the query string" do
      sequence([ok("[]")])

      Application.put_env(:razorpay_ex, :enable_logging, true)

      log =
        capture_log(fn ->
          Client.request(:get, "/payments", %{}, params: %{email: "customer@example.com"})
        end)

      assert log =~ "razorpay_ex GET /v1/payments -> 200"
      refute log =~ "customer@example.com"
    end

    test "stays silent when logging is disabled" do
      sequence([ok("[]")])

      log = capture_log(fn -> Client.request(:get, "/payments") end)

      refute log =~ "razorpay_ex"
    end
  end

  describe "pagination" do
    test "walks pages until a short page and returns every item" do
      sequence([ok(page(2, 1)), ok(page(2, 3)), ok(page(1, 5))])

      assert {:ok, payments} = Paginator.all(:payment, %{}, page_size: 2)
      assert Enum.map(payments, & &1.id) == ["pay_1", "pay_2", "pay_3", "pay_4", "pay_5"]
      assert Enum.all?(payments, &match?(%Payment{}, &1))
    end

    test "stops after a single short page" do
      sequence([ok(page(1, 1))])

      assert {:ok, [%Payment{id: "pay_1"}]} = Paginator.all(:payment, %{count: 10}, page_size: 5)
    end

    test "passes count and skip, overriding caller-supplied values" do
      expect(RazorpayEx.HttpClientMock, :request, fn _method, url, _body, _headers, _opts ->
        assert url =~ "count=2"
        assert url =~ "skip=0"
        refute url =~ "skip=99"
        ok(page(1, 3))
      end)

      assert {:ok, [_]} =
               Paginator.all(:payment, %{skip: 99, count: 99}, page_size: 2, max_pages: 1)
    end

    test "returns an error when max_pages is reached" do
      sequence([ok(page(2, 1))])

      assert {:error, %{code: "PAGINATION_LIMIT"}} =
               Paginator.all(:payment, %{}, page_size: 2, max_pages: 1)
    end

    test "propagates API errors" do
      sequence([ok(~s({"error":{"code":"SERVER_ERROR","description":"boom"}}), 500)])

      assert {:error, %{code: "SERVER_ERROR"}} = Paginator.all(:payment)
    end

    test "validates page_size" do
      assert {:error, %{code: "INVALID_PAGE_SIZE"}} = Paginator.all(:payment, %{}, page_size: 0)
      assert {:error, %{code: "INVALID_PAGE_SIZE"}} = Paginator.all(:payment, %{}, page_size: 101)
      assert {:error, %{code: "INVALID_MAX_PAGES"}} = Paginator.all(:payment, %{}, max_pages: 0)
    end

    test "accepts an explicit path" do
      expect(RazorpayEx.HttpClientMock, :request, fn _m, url, _b, _h, _o ->
        assert String.starts_with?(url, "https://api.razorpay.com/v1/refunds?")
        ok(page(1, 1))
      end)

      assert {:ok, [_]} = Paginator.all("/refunds")
    end
  end

  describe "refund idempotency" do
    test "sends X-Refund-Idempotency when an idempotency key is given" do
      expect(RazorpayEx.HttpClientMock, :request, fn _method, _url, _body, headers, _opts ->
        assert {"x-refund-idempotency", "550e8400-e29b-41d4"} in headers
        ok(~s({"entity":"refund","id":"rfnd_1","amount":100}))
      end)

      assert {:ok, %Refund{id: "rfnd_1"}} =
               Refund.create("pay_1", %{amount: 100}, idempotency_key: "550e8400-e29b-41d4")
    end

    test "omits the header when no idempotency key is given" do
      expect(RazorpayEx.HttpClientMock, :request, fn _method, _url, _body, headers, _opts ->
        refute List.keymember?(headers, "x-refund-idempotency", 0)
        ok(~s({"entity":"refund","id":"rfnd_1"}))
      end)

      assert {:ok, %Refund{id: "rfnd_1"}} = Refund.create("pay_1", %{amount: 100})
    end

    test "keeps caller supplied headers" do
      expect(RazorpayEx.HttpClientMock, :request, fn _method, _url, _body, headers, _opts ->
        assert {"x-custom", "v"} in headers
        assert {"x-refund-idempotency", "abcdefghij"} in headers
        ok(~s({"entity":"refund","id":"rfnd_1"}))
      end)

      assert {:ok, %Refund{}} =
               Refund.create("pay_1", %{},
                 idempotency_key: "abcdefghij",
                 headers: [{"X-Custom", "v"}]
               )
    end
  end
end
