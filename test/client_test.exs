defmodule RazorpayEx.ClientTest do
  use ExUnit.Case
  import Mox

  # Make sure Mox is configured in test_helper.exs
  setup :verify_on_exit!

  # Reset application env before each test
  setup do
    # DON'T use stub_with - it's causing the issue
    # :ok = Mox.stub_with(RazorpayEx.HttpClientMock, RazorpayEx.HttpClientMock)

    # Set default basic auth for most tests
    Application.put_env(:razorpay_ex, :auth_type, :basic)
    Application.put_env(:razorpay_ex, :key_id, "test_key_id")
    Application.put_env(:razorpay_ex, :key_secret, "test_key_secret")
    Application.delete_env(:razorpay_ex, :access_token)
    Application.delete_env(:razorpay_ex, :custom_headers)

    :ok
  end

  describe "request/4" do
    test "handles successful response" do
      # Use expect/3 without count parameter
      expect(RazorpayEx.HttpClientMock, :request, fn :get, url, "", headers, opts ->
        # Verify URL
        assert url == "https://api.razorpay.com/v1/payments/pay_test_123"

        # Verify Basic Auth header
        assert {"authorization", "Basic " <> auth} = List.keyfind(headers, "authorization", 0)
        assert Base.decode64!(auth) == "test_key_id:test_key_secret"

        {:ok,
         %{
           status_code: 200,
           body: """
           {
             "id": "pay_test_123",
             "entity": "payment",
             "amount": 50000,
             "currency": "INR",
             "status": "captured"
           }
           """,
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, payment} = RazorpayEx.Client.request(:get, "/payments/pay_test_123")
      assert payment.id == "pay_test_123"
      assert payment.amount == 50000
      assert payment.entity == "payment"
    end

    test "handles POST request" do
      order_data = %{amount: 50000, currency: "INR", receipt: "test_123"}

      expect(RazorpayEx.HttpClientMock, :request, fn :post, url, body, _headers, _opts ->
        # Verify URL
        assert url == "https://api.razorpay.com/v1/orders"

        # Verify JSON body
        assert Jason.decode!(body) == %{
          "amount" => 50000,
          "currency" => "INR",
          "receipt" => "test_123"
        }

        {:ok,
         %{
           status_code: 201,
           body: """
           {
             "id": "order_test_456",
             "entity": "order",
             "amount": 50000,
             "currency": "INR",
             "receipt": "test_123",
             "status": "created"
           }
           """,
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, order} = RazorpayEx.Client.request(:post, "/orders", order_data)
      assert order.id == "order_test_456"
      assert order.amount == 50000
      assert order.entity == "order"
    end

    test "handles error response" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %{
           status_code: 400,
           body: """
           {
             "error": {
               "code": "BAD_REQUEST_ERROR",
               "description": "Invalid payment ID"
             }
           }
           """,
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST_ERROR"}} =
               RazorpayEx.Client.request(:get, "/payments/invalid_id")
    end

    test "handles network error" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:error, %{reason: :econnrefused}}
      end)

      assert {:error, %RazorpayEx.Error{code: "NETWORK_ERROR"}} =
               RazorpayEx.Client.request(:get, "/payments/pay_test_123")
    end

    test "includes authentication headers for basic auth" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, headers, _opts ->
        # Verify Basic Auth header is present
        assert {"authorization", "Basic " <> auth} =
                 List.keyfind(headers, "authorization", 0)
        assert Base.decode64!(auth) == "test_key_id:test_key_secret"

        {:ok,
         %{
           status_code: 200,
           body: "{}",
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, _} = RazorpayEx.Client.request(:get, "/payments")
    end

    test "includes authentication headers for OAuth" do
      # Setup OAuth for this specific test
      Application.put_env(:razorpay_ex, :auth_type, :oauth)
      Application.put_env(:razorpay_ex, :access_token, "oauth_token_123")
      Application.delete_env(:razorpay_ex, :key_id)
      Application.delete_env(:razorpay_ex, :key_secret)

      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, headers, _opts ->
        # Verify Bearer token header is present
        assert {"authorization", "Bearer oauth_token_123"} =
                 List.keyfind(headers, "authorization", 0)

        {:ok,
         %{
           status_code: 200,
           body: "{}",
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, _} = RazorpayEx.Client.request(:get, "/payments")
    end

    test "includes custom headers" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, headers, _opts ->
        # Verify custom headers (with lowercased keys)
        assert {"x-custom-header", "custom_value"} in headers
        assert {"x-another-header", "another_value"} in headers

        {:ok,
        %{
          status_code: 200,
          body: "{}",
          headers: [{"content-type", "application/json"}]
        }}
      end)

      # Configure custom headers
      Application.put_env(:razorpay_ex, :custom_headers, %{
        "X-Custom-Header" => "custom_value",
        "X-Another-Header" => "another_value"
      })

      assert {:ok, _} = RazorpayEx.Client.request(:get, "/payments")
    end

    test "handles query parameters" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, url, _body, _headers, opts ->
        # Verify URL
        assert url == "https://api.razorpay.com/v1/payments"

        # Verify params are passed (they're atoms, not strings)
        assert opts[:params] == %{count: 10, skip: 0}  # Changed from string keys to atom keys

        {:ok,
        %{
          status_code: 200,
          body: "[]",
          headers: [{"content-type", "application/json"}]
        }}
      end)

      assert {:ok, []} = RazorpayEx.Client.request(:get, "/payments", %{}, params: %{count: 10, skip: 0})
    end

    test "returns empty map for empty response body" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %{
           status_code: 200,
           body: "",
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, %{}} = RazorpayEx.Client.request(:get, "/payments")
    end

    test "handles invalid JSON response" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %{
           status_code: 200,
           body: "invalid json",
           headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:error, %RazorpayEx.Error{code: "INVALID_JSON"}} =
               RazorpayEx.Client.request(:get, "/payments")
    end
  end

  describe "raw_request/4" do
    test "returns raw response without transformation" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %{
           status_code: 200,
           body: "raw response",
           headers: [{"content-type", "text/plain"}]
         }}
      end)

      assert {:ok, %{status_code: 200, body: "raw response"}} =
               RazorpayEx.Client.raw_request(:get, "/payments")
    end
  end
end
