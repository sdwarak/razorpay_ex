defmodule RazorpayEx.UtilityTest do
  use ExUnit.Case, async: true

  alias RazorpayEx.{Signature, Utility}

  @secret "rzp_test_secret"

  defp sign(data, secret \\ @secret), do: Signature.hmac_sha256(data, secret)

  describe "verify_payment_signature/3,4" do
    test "accepts the signature Razorpay produces for order|payment" do
      signature = sign("order_1|pay_1")

      assert Utility.verify_payment_signature("order_1", "pay_1", signature, @secret)
    end

    test "rejects a signature computed over the wrong data" do
      # Reversed ids are the classic mistake: order comes first.
      refute Utility.verify_payment_signature("order_1", "pay_1", sign("pay_1|order_1"), @secret)

      refute Utility.verify_payment_signature(
               "order_1",
               "pay_1",
               sign("order_1|pay_1", "other"),
               @secret
             )

      refute Utility.verify_payment_signature("order_1", "pay_1", "not-a-signature", @secret)
    end

    test "never raises on missing or non-binary values" do
      refute Utility.verify_payment_signature(nil, "pay_1", "sig", @secret)
      refute Utility.verify_payment_signature("order_1", nil, "sig", @secret)
      refute Utility.verify_payment_signature("order_1", "pay_1", nil, @secret)
      refute Utility.verify_payment_signature("order_1", "pay_1", "sig", nil)
    end
  end

  describe "verify_payment_signature/1,2 (Checkout params)" do
    test "reads string keys from a params map" do
      params = %{
        "razorpay_order_id" => "order_1",
        "razorpay_payment_id" => "pay_1",
        "razorpay_signature" => sign("order_1|pay_1")
      }

      assert Utility.verify_payment_signature(params, @secret)
    end

    test "reads atom keys" do
      params = %{
        razorpay_order_id: "order_1",
        razorpay_payment_id: "pay_1",
        razorpay_signature: sign("order_1|pay_1")
      }

      assert Utility.verify_payment_signature(params, @secret)
    end

    test "returns false when a param is missing" do
      params = %{"razorpay_order_id" => "order_1", "razorpay_signature" => sign("order_1|pay_1")}

      refute Utility.verify_payment_signature(params, @secret)
    end

    test "returns false when the signature is wrong" do
      params = %{
        "razorpay_order_id" => "order_1",
        "razorpay_payment_id" => "pay_1",
        "razorpay_signature" => sign("order_1|pay_1", "attacker")
      }

      refute Utility.verify_payment_signature(params, @secret)
    end
  end

  describe "verify_subscription_signature/3,4" do
    test "signs payment|subscription" do
      signature = sign("pay_1|sub_1")

      assert Utility.verify_subscription_signature("pay_1", "sub_1", signature, @secret)
      refute Utility.verify_subscription_signature("sub_1", "pay_1", signature, @secret)
    end
  end

  describe "verify_payment_link_signature/4,5" do
    test "signs link|reference|status" do
      signature = sign("plink_1|ref_1|paid")

      assert Utility.verify_payment_link_signature("plink_1", "ref_1", "paid", signature, @secret)

      refute Utility.verify_payment_link_signature(
               "plink_1",
               "ref_1",
               "cancelled",
               signature,
               @secret
             )
    end
  end

  describe "verify_webhook_signature/3" do
    test "matches RazorpayEx.Webhook.verify/3" do
      payload = ~s({"event":"payment.captured"})
      signature = RazorpayEx.Webhook.generate_signature(payload, "whsec")

      assert Utility.verify_webhook_signature(payload, signature, "whsec")
      refute Utility.verify_webhook_signature(payload, signature, "wrong")
    end
  end

  describe "timing safety" do
    test "compares signatures of different lengths without raising" do
      refute Signature.valid?(sign("a"), "short")
      refute Signature.valid?(sign("a"), String.duplicate("x", 10_000))
      assert Signature.valid?(sign("a"), sign("a"))
    end
  end
end

defmodule RazorpayEx.UtilityConfigTest do
  # Touches application environment, so it cannot run concurrently.
  use ExUnit.Case, async: false

  alias RazorpayEx.{Signature, Utility}

  setup do
    previous = Application.fetch_env(:razorpay_ex, :key_secret)
    Application.put_env(:razorpay_ex, :key_secret, "rzp_test_secret")

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:razorpay_ex, :key_secret, value)
        :error -> Application.delete_env(:razorpay_ex, :key_secret)
      end
    end)
  end

  test "falls back to the configured key secret" do
    signature = Signature.hmac_sha256("order_1|pay_1", "rzp_test_secret")

    assert Utility.verify_payment_signature("order_1", "pay_1", signature)

    assert Utility.verify_payment_signature(%{
             "razorpay_order_id" => "order_1",
             "razorpay_payment_id" => "pay_1",
             "razorpay_signature" => signature
           })
  end
end
