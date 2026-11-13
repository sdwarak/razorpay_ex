defmodule RazorpayEx.ResponseMappingTest do
  @moduledoc """
  Tests how API payloads are turned into Elixir values.

  The HTTP client is mocked, so these tests focus purely on the mapping layer:
  collections, lossless entity casting, error mapping, header handling and query
  encoding.
  """

  use ExUnit.Case, async: false
  import Mox

  alias RazorpayEx.{Client, Config, Customer, Entity, Error, Order, Payment, Query, Refund}

  setup :verify_on_exit!

  setup do
    previous =
      Map.new(
        [:api_base_url, :api_url, :key_id, :key_secret, :auth_type, :custom_headers, :timeout],
        fn key ->
          {key, Application.fetch_env(:razorpay_ex, key)}
        end
      )

    Application.put_env(:razorpay_ex, :auth_type, :basic)
    Application.put_env(:razorpay_ex, :key_id, "test_key_id")
    Application.put_env(:razorpay_ex, :key_secret, "test_key_secret")
    Application.put_env(:razorpay_ex, :api_base_url, "https://api.razorpay.com/v1")
    Application.delete_env(:razorpay_ex, :api_url)
    Application.delete_env(:razorpay_ex, :custom_headers)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:razorpay_ex, key, value)
        {key, :error} -> Application.delete_env(:razorpay_ex, key)
      end)
    end)

    :ok
  end

  defp respond(body, status \\ 200) do
    expect(RazorpayEx.HttpClientMock, :request, fn _method, _url, _body, _headers, _opts ->
      {:ok, %{status_code: status, body: body, headers: [{"content-type", "application/json"}]}}
    end)
  end

  describe "collections" do
    test "list endpoints return the items as entities" do
      respond(
        ~s({"entity":"collection","count":2,"items":[{"entity":"payment","id":"pay_1","amount":100},{"entity":"payment","id":"pay_2","amount":200}]})
      )

      assert {:ok, [%Payment{id: "pay_1", amount: 100}, %Payment{id: "pay_2", amount: 200}]} =
               Payment.all(%{count: 2})
    end

    test "an empty collection becomes an empty list" do
      respond(~s({"entity":"collection","count":0,"items":[]}))

      assert {:ok, []} = Order.all()
    end

    test "a collection without items becomes an empty list" do
      respond(~s({"entity":"collection","count":0}))

      assert {:ok, []} = Refund.all()
    end

    test "nested collections (order payments, payment refunds) work too" do
      respond(
        ~s({"entity":"collection","count":1,"items":[{"entity":"refund","id":"rfnd_1","amount":50}]})
      )

      respond(
        ~s({"entity":"collection","count":1,"items":[{"entity":"refund","id":"rfnd_1","amount":50}]})
      )

      assert {:ok, [%Refund{id: "rfnd_1", amount: 50}]} = Refund.for_payment("pay_1")
      assert {:ok, [%Refund{id: "rfnd_1", amount: 50}]} = Order.payments("order_1")
    end
  end

  describe "entity casting" do
    test "known fields are typed and unknown fields are kept in :extra" do
      respond(
        ~s({"entity":"payment","id":"pay_1","amount":500,"status":"captured","acquirer_data":{"rrn":"123"},"upi":{"vpa":"a@b"}})
      )

      assert {:ok, payment} = Payment.fetch("pay_1")
      assert %Payment{id: "pay_1", amount: 500, status: "captured"} = payment
      assert payment.extra == %{"acquirer_data" => %{"rrn" => "123"}, "upi" => %{"vpa" => "a@b"}}
    end

    test "entity types without a module keep every field" do
      respond(~s({"entity":"invoice","id":"inv_1","amount":100,"status":"issued"}))

      assert {:ok, %Entity{id: "inv_1"} = invoice} = Client.request(:get, "/invoices/inv_1")
      assert invoice.extra == %{"amount" => 100, "status" => "issued"}
    end

    test "customer payloads are typed" do
      respond(~s({"entity":"customer","id":"cust_1","name":"Ada","email":"ada@example.com"}))

      assert {:ok, %Customer{id: "cust_1", name: "Ada", email: "ada@example.com"}} =
               Customer.fetch("cust_1")
    end

    test "empty bodies map to an empty map" do
      respond("")

      assert {:ok, %{}} = Client.request(:delete, "/customers/cust_1")
    end

    test "invalid JSON is a typed error" do
      respond("not json")

      assert {:error, %Error{code: "INVALID_JSON"}} = Client.request(:get, "/payments/pay_1")
    end
  end

  describe "error mapping" do
    test "API errors become RazorpayEx.Error with every field" do
      respond(
        ~s({"error":{"code":"BAD_REQUEST_ERROR","description":"Invalid payment id","field":"id","step":"payment_init","reason":"input_validation_failed","metadata":{"payment_id":"pay_bad"}}}),
        400
      )

      assert {:error, %Error{} = error} = Payment.fetch("pay_bad")
      assert error.code == "BAD_REQUEST_ERROR"
      assert error.description == "Invalid payment id"
      assert error.field == "id"
      assert error.step == "payment_init"
      assert error.reason == "input_validation_failed"
      assert error.metadata == %{"payment_id" => "pay_bad"}
      assert error.http_status_code == 400
      assert error.http_body =~ "BAD_REQUEST_ERROR"
    end

    test "error codes are preserved verbatim" do
      respond(~s({"error":{"code":"GATEWAY_ERROR","description":"Down"}}), 502)

      assert {:error, %Error{code: "GATEWAY_ERROR", http_status_code: 502}} =
               Client.request(:get, "/payments")
    end

    test "non-JSON error bodies still produce an error" do
      respond("<html>Bad Gateway</html>", 502)

      assert {:error, %Error{code: "HTTP_502"}} = Client.request(:get, "/payments")
    end

    test "the optional exception modules are available" do
      assert %RazorpayEx.Errors.GatewayError{code: "GATEWAY_ERROR"} =
               RazorpayEx.Errors.GatewayError.exception(description: "Down")

      assert %RazorpayEx.Errors.BadRequestError{http_status_code: 400} =
               RazorpayEx.Errors.BadRequestError.exception(description: "Bad")

      assert %RazorpayEx.Errors.ServerError{http_status_code: 500} =
               RazorpayEx.Errors.ServerError.exception(description: "Oops")
    end
  end

  describe "headers" do
    test "custom headers configured through RazorpayEx.headers/1 are sent" do
      RazorpayEx.headers(%{"X-Razorpay-Account" => "acc_123"})

      expect(RazorpayEx.HttpClientMock, :request, fn _method, _url, _body, headers, _opts ->
        assert {"x-razorpay-account", "acc_123"} in headers
        {:ok, %{status_code: 200, body: "[]", headers: []}}
      end)

      assert {:ok, []} = Client.request(:get, "/payments")
    end

    test "request headers override configured headers, which override defaults" do
      Application.put_env(:razorpay_ex, :custom_headers, %{"User-Agent" => "configured/1.0"})

      expect(RazorpayEx.HttpClientMock, :request, fn _method, _url, _body, headers, _opts ->
        assert {"user-agent", "request/2.0"} in headers
        assert {"content-type", "application/json"} in headers
        {:ok, %{status_code: 200, body: "[]", headers: []}}
      end)

      assert {:ok, []} =
               Client.request(:get, "/payments", %{}, headers: %{"User-Agent" => "request/2.0"})
    end
  end

  describe "query encoding" do
    test "scalar and list values" do
      assert Query.encode(%{count: 10}) == "count=10"

      assert Query.encode(%{expand: ["card", "offer"]}) ==
               "expand%5B%5D=card&expand%5B%5D=offer"
    end

    test "expand is always sent as expand[]" do
      assert Query.encode(%{expand: "card"}) == "expand%5B%5D=card"
    end

    test "nil values are dropped" do
      assert Query.encode(%{count: 10, skip: nil}) == "count=10"
      assert Query.encode(%{}) == ""
      assert Query.encode(nil) == ""
    end

    test "arbitrary lists are sent as repeated key[] parameters" do
      assert Query.encode(%{"receipt[]" => ["a", "b"]}) == "receipt%5B%5D=a&receipt%5B%5D=b"
    end

    test "params end up in the request URL" do
      expect(RazorpayEx.HttpClientMock, :request, fn _method, url, _body, _headers, _opts ->
        assert url =~ "https://api.razorpay.com/v1/payments?"
        assert url =~ "count=10"
        assert url =~ "expand%5B%5D=card"
        {:ok, %{status_code: 200, body: "[]", headers: []}}
      end)

      assert {:ok, []} =
               Client.request(:get, "/payments", %{}, params: %{count: 10, expand: ["card"]})
    end
  end

  describe "legacy request facade" do
    test "Request.all/3 and Entity.all/2 build resource paths" do
      expect(RazorpayEx.HttpClientMock, :request, 2, fn _method, url, _body, _headers, _opts ->
        assert url =~ ~r"https://api.razorpay.com/v1/payments\?count=1$"

        {:ok,
         %{status_code: 200, body: ~s({"entity":"collection","count":1,"items":[]}), headers: []}}
      end)

      assert {:ok, []} = RazorpayEx.Request.all(:payment, %{count: 1})
      assert {:ok, []} = Entity.all(:payment, %{count: 1})
    end

    test "Entity.fetch/2 builds the resource path" do
      expect(RazorpayEx.HttpClientMock, :request, fn _method, url, _body, _headers, _opts ->
        assert url == "https://api.razorpay.com/v1/orders/order_1"
        {:ok, %{status_code: 200, body: ~s({"entity":"order","id":"order_1"}), headers: []}}
      end)

      assert {:ok, %Order{id: "order_1"}} = Entity.fetch("order_1", :order)
    end
  end

  describe "configuration" do
    test "the legacy :api_url key is still honoured" do
      Application.delete_env(:razorpay_ex, :api_base_url)
      Application.put_env(:razorpay_ex, :api_url, "https://sandbox.example.com/v1")

      assert Config.api_base_url() == "https://sandbox.example.com/v1"
    end

    test ":api_base_url wins over :api_url" do
      Application.put_env(:razorpay_ex, :api_url, "https://sandbox.example.com/v1")

      assert Config.api_base_url() == "https://api.razorpay.com/v1"
    end

    test "the user agent carries the library version" do
      assert RazorpayEx.Constants.user_agent() =~ ~r"^razorpay-ex/\d+\.\d+\.\d+$"
    end

    test "endpoint paths are pluralised without an inflection dependency" do
      assert RazorpayEx.Constants.endpoint_path(:payment) == "payments"
      assert RazorpayEx.Constants.endpoint_path(:customer) == "customers"
      assert RazorpayEx.Constants.endpoint_path(:qr_code) == "qr_codes"
      assert RazorpayEx.Constants.endpoint_path(:payment_link) == "payment_links"
      assert RazorpayEx.Constants.endpoint_path(:unknown_resource) == "unknown_resources"
    end
  end
end
