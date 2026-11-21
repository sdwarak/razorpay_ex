defmodule RazorpayEx.SecurityTest do
  use ExUnit.Case, async: false
  import Mox

  alias RazorpayEx.{Client, Config, Customer, Entity, Order, Payment, Refund, Utility, Webhook}

  setup :verify_on_exit!

  setup do
    Application.put_env(:razorpay_ex, :auth_type, :basic)
    Application.put_env(:razorpay_ex, :key_id, "test_key_id")
    Application.put_env(:razorpay_ex, :key_secret, "test_key_secret")
    Application.delete_env(:razorpay_ex, :access_token)
    Application.delete_env(:razorpay_ex, :custom_headers)
    :ok
  end

  describe "webhook signature verification robustness (SEC-01)" do
    test "never raises on missing or nil signature" do
      refute Webhook.verify("payload", nil, "secret")
      refute Utility.verify_webhook_signature("payload", nil, "secret")
    end

    test "never raises on missing or nil secret" do
      refute Webhook.verify("payload", "sig", nil)
      refute Utility.verify_webhook_signature("payload", "sig", nil)
    end

    test "never raises on nil payload" do
      refute Webhook.verify(nil, "sig", "secret")
      refute Utility.verify_webhook_signature(nil, "sig", "secret")
    end

    test "never raises on non-binary types" do
      refute Webhook.verify(123, %{}, :secret)
      refute Utility.verify_webhook_signature(123, %{}, :secret)
    end

    test "supports single-item list as returned by Plug.Conn.get_req_header" do
      payload = ~s({"event":"payment.captured"})
      secret = "whsec_test"
      signature = Webhook.generate_signature(payload, secret)

      assert Webhook.verify(payload, [signature], secret)
      refute Webhook.verify(payload, ["invalid_sig"], secret)
    end

    test "extract_signature handles case-insensitivity and list values" do
      assert Webhook.extract_signature(%{"X-Razorpay-Signature" => "sig1"}) == "sig1"
      assert Webhook.extract_signature(%{"x-razorpay-signature" => "sig2"}) == "sig2"
      assert Webhook.extract_signature([{"x-razorpay-signature", "sig3"}]) == "sig3"
      assert Webhook.extract_signature([{"x-razorpay-signature", ["sig4"]}]) == "sig4"
      assert Webhook.extract_signature(%{"other" => "val"}) == nil
      assert Webhook.extract_signature(nil) == nil
    end
  end

  describe "credential inspection masking (SEC-02)" do
    test "inspecting %Config{} masks key_secret and access_token" do
      Config.set(%{
        key_id: "public_key_123",
        key_secret: "super_secret_key_456",
        access_token: "super_secret_token_789"
      })

      config = Config.get()
      inspected = inspect(config)

      assert inspected =~ "public_key_123"
      refute inspected =~ "super_secret_key_456"
      refute inspected =~ "super_secret_token_789"
    end
  end

  describe "endpoint URL encoding & ID validation (SEC-03)" do
    test "fetch rejects nil and empty IDs" do
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Payment.fetch(nil)
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Payment.fetch("")
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Order.fetch(nil)
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Order.fetch("")
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Refund.fetch(nil)
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Refund.fetch("")
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Customer.fetch(nil)
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Customer.fetch("")
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Entity.fetch(nil, :payment)
      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} = Entity.fetch("", :payment)

      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} =
               RazorpayEx.Request.fetch(:payment, nil)

      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST"}} =
               RazorpayEx.Request.fetch(:payment, "")
    end

    test "URL encodes special characters in IDs to prevent traversal" do
      expect(RazorpayEx.HttpClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url == "https://api.razorpay.com/v1/payments/pay_123%2Fcapture"

        {:ok,
         %{status_code: 200, body: ~s({"id":"pay_123/capture","entity":"payment"}), headers: []}}
      end)

      assert {:ok, _} = Payment.fetch("pay_123/capture")
    end
  end

  describe "per-request credential override (SEC-05)" do
    test "allows overriding credentials per request" do
      Application.put_env(:razorpay_ex, :key_id, "global_key")
      Application.put_env(:razorpay_ex, :key_secret, "global_secret")

      expect(RazorpayEx.HttpClientMock, :request, fn :get, _url, _body, headers, _opts ->
        assert {"authorization", "Basic " <> encoded} = List.keyfind(headers, "authorization", 0)
        assert Base.decode64!(encoded) == "per_request_key:per_request_secret"
        {:ok, %{status_code: 200, body: "[]", headers: []}}
      end)

      assert {:ok, []} =
               Client.request(:get, "/payments", %{},
                 key_id: "per_request_key",
                 key_secret: "per_request_secret"
               )
    end
  end
end
