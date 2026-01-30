defmodule RazorpayExTest do
  use ExUnit.Case
  doctest RazorpayEx

  test "version/0 returns the version" do
    assert RazorpayEx.version() =~ ~r/\d+\.\d+\.\d+/
  end

  test "verify_webhook/3 returns boolean" do
    payload = "test_payload"
    secret = "test_secret"
    signature = RazorpayEx.Webhook.generate_signature(payload, secret)

    assert RazorpayEx.verify_webhook(payload, signature, secret) == true
    assert RazorpayEx.verify_webhook(payload, "invalid_signature", secret) == false
  end
end
