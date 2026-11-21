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

  alias RazorpayEx.Signature

  @doc """
  Verifies a webhook signature.

  ## Parameters

    - `payload`: Raw webhook payload body
    - `signature`: The `x-razorpay-signature` header value (string or header list)
    - `secret`: Your webhook secret from Razorpay dashboard

  ## Returns

    - `true` if signature is valid
    - `false` if signature is invalid or any parameter is invalid/missing

  ## Examples

      # Verify signature
      RazorpayEx.Webhook.verify(payload, signature, "webhook_secret_123")
  """
  @spec verify(String.t(), String.t() | list(String.t()) | nil, String.t()) :: boolean()
  def verify(payload, [signature | _], secret) when is_binary(signature),
    do: verify(payload, signature, secret)

  def verify(payload, signature, secret)
      when is_binary(payload) and is_binary(signature) and is_binary(secret) do
    Signature.valid?(generate_signature(payload, secret), signature)
  end

  def verify(_payload, _signature, _secret), do: false

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
    Signature.hmac_sha256(payload, secret)
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
    Enum.find_value(headers, fn {k, v} -> match_signature_header(k, v) end)
  end

  def extract_signature(headers) when is_list(headers) do
    Enum.find_value(headers, fn
      {k, v} -> match_signature_header(k, v)
      _ -> nil
    end)
  end

  def extract_signature(_headers), do: nil

  defp match_signature_header(key, value) do
    if String.downcase(to_string(key)) == "x-razorpay-signature" do
      unwrap_header_value(value)
    end
  end

  defp unwrap_header_value([first | _]) when is_binary(first), do: first
  defp unwrap_header_value(value) when is_binary(value), do: value
  defp unwrap_header_value(_), do: nil
end
