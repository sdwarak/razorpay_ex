defmodule RazorpayEx.Webhook do
  @moduledoc """
  Webhook verification for Razorpay.

  This module provides utilities for verifying webhook signatures to ensure
  that webhooks are genuinely from Razorpay.

  ## Usage

      # Verify webhook signature
      signature = get_req_header("x-razorpay-signature")
      body = get_req_body()

      if Razorpay.Webhook.verify(body, signature, "your_webhook_secret") do
        # Process webhook
        process_webhook(body)
      else
        # Invalid signature
        {:error, :invalid_signature}
      end

  ## Note

  Always verify webhook signatures in production to prevent unauthorized requests.
  """

  @doc """
  Verifies a webhook signature.

  ## Parameters

    - `payload`: Raw webhook payload body
    - `signature`: The `x-razorpay-signature` header value
    - `secret`: Your webhook secret from Razorpay dashboard

  ## Returns

    - `true` if signature is valid
    - `false` if signature is invalid

  ## Examples

      # Verify signature
      RazorpayEx.Webhook.verify(payload, signature, "webhook_secret_123")
  """
  @spec verify(String.t(), String.t(), String.t()) :: boolean()
  def verify(payload, signature, secret) do
    expected_signature = generate_signature(payload, secret)
    expected_signature == signature
  end

  @doc """
  Generates a webhook signature for a payload.

  ## Parameters

    - `payload`: Raw webhook payload body
    - `secret`: Webhook secret

  ## Returns

    - Hexadecimal signature string

  ## Examples

      signature = Razorpay.Webhook.generate_signature(payload, "secret")
  """
  @spec generate_signature(String.t(), String.t()) :: String.t()
  def generate_signature(payload, secret) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Extracts webhook signature from headers.

  ## Parameters

    - `headers`: Map or keyword list of headers

  ## Returns

    - Signature string or nil if not found

  ## Examples

      signature = Razorpay.Webhook.extract_signature(%{"x-razorpay-signature" => "sig_123"})
  """
  @spec extract_signature(map() | keyword()) :: String.t() | nil
  def extract_signature(headers) when is_map(headers) do
    headers["x-razorpay-signature"]
  end

  def extract_signature(headers) when is_list(headers) do
    headers
    |> Enum.find(fn {k, _} -> String.downcase(k) == "x-razorpay-signature" end)
    |> case do
      {_, value} -> value
      nil -> nil
    end
  end
end
