defmodule RazorpayEx.Utility do
  @moduledoc """
  Signature verification for Razorpay Checkout callbacks.

  Razorpay signs two different things and they must not be confused:

    * **Checkout callbacks** are signed with your **key secret**. The browser
      handler receives `razorpay_order_id`, `razorpay_payment_id` and
      `razorpay_signature`; verify them with `verify_payment_signature/1`
      before you trust the payment.
    * **Webhooks** are signed with the **webhook secret** and cover the raw
      request body. Verify them with `verify_webhook_signature/3` (or
      `RazorpayEx.Webhook.verify/3`).

  Every function returns a boolean and never raises on a bad signature, so a
  failed check cannot be mistaken for a successful one by a caller that forgets
  to handle an exception.

  The secret defaults to the configured key secret
  (`RazorpayEx.Config.key_secret/0`); pass it explicitly if you keep it
  elsewhere.

  ## Examples

      # In a Phoenix controller, from the Checkout handler
      if RazorpayEx.Utility.verify_payment_signature(params) do
        fulfil_order(params["razorpay_order_id"])
      else
        send_resp(conn, 400, "invalid signature")
      end

      # Explicit ids and secret
      RazorpayEx.Utility.verify_payment_signature(order_id, payment_id, signature, secret)
  """

  alias RazorpayEx.{Config, Signature, Webhook}

  @signature_params {"razorpay_signature", :razorpay_signature}
  @order_params {"razorpay_order_id", :razorpay_order_id}
  @payment_params {"razorpay_payment_id", :razorpay_payment_id}

  @doc """
  Verifies a Checkout payment signature from the callback parameters.

  Accepts the params map as received (string keys, atom keys, or a mix) and
  returns `false` when any of the three values is missing.

  ## Examples

      RazorpayEx.Utility.verify_payment_signature(%{
        "razorpay_order_id" => "order_1",
        "razorpay_payment_id" => "pay_1",
        "razorpay_signature" => "..."
      })
  """
  @spec verify_payment_signature(map() | keyword()) :: boolean()
  def verify_payment_signature(params) when is_map(params) or is_list(params) do
    verify_payment_signature(params, Config.key_secret())
  end

  @doc """
  Same as `verify_payment_signature/1` with an explicit key secret.
  """
  @spec verify_payment_signature(map() | keyword(), String.t()) :: boolean()
  def verify_payment_signature(params, secret) when is_map(params) or is_list(params) do
    with {:ok, order_id} <- fetch_param(params, @order_params),
         {:ok, payment_id} <- fetch_param(params, @payment_params),
         {:ok, signature} <- fetch_param(params, @signature_params) do
      verify_payment_signature(order_id, payment_id, signature, secret)
    else
      _ -> false
    end
  end

  @doc """
  Verifies a Checkout payment signature from explicit values, using the
  configured key secret.
  """
  @spec verify_payment_signature(String.t(), String.t(), String.t()) :: boolean()
  def verify_payment_signature(order_id, payment_id, signature)
      when is_binary(order_id) and is_binary(payment_id) and is_binary(signature) do
    verify_payment_signature(order_id, payment_id, signature, Config.key_secret())
  end

  @doc """
  Verifies a Checkout payment signature from explicit values and secret.

  The signed payload is `"<order_id>|<payment_id>"`.
  """
  @spec verify_payment_signature(String.t(), String.t(), String.t(), String.t()) :: boolean()
  def verify_payment_signature(order_id, payment_id, signature, secret)
      when is_binary(order_id) and is_binary(payment_id) and is_binary(signature) and
             is_binary(secret) do
    verify("#{order_id}|#{payment_id}", signature, secret)
  end

  def verify_payment_signature(_order_id, _payment_id, _signature, _secret), do: false

  @doc """
  Verifies a Checkout subscription signature.

  The signed payload is `"<payment_id>|<subscription_id>"`, which is the order
  Razorpay uses for subscription authorisation callbacks.
  """
  @spec verify_subscription_signature(String.t(), String.t(), String.t()) :: boolean()
  def verify_subscription_signature(payment_id, subscription_id, signature)
      when is_binary(payment_id) and is_binary(subscription_id) and is_binary(signature) do
    verify_subscription_signature(payment_id, subscription_id, signature, Config.key_secret())
  end

  @spec verify_subscription_signature(String.t(), String.t(), String.t(), String.t()) :: boolean()
  def verify_subscription_signature(payment_id, subscription_id, signature, secret)
      when is_binary(payment_id) and is_binary(subscription_id) and is_binary(signature) and
             is_binary(secret) do
    verify("#{payment_id}|#{subscription_id}", signature, secret)
  end

  def verify_subscription_signature(_payment_id, _subscription_id, _signature, _secret), do: false

  @doc """
  Verifies a Payment Link signature.

  The signed payload is
  `"<payment_link_id>|<payment_link_reference_id>|<payment_link_status>"`.
  """
  @spec verify_payment_link_signature(String.t(), String.t(), String.t(), String.t()) :: boolean()
  def verify_payment_link_signature(link_id, reference_id, status, signature)
      when is_binary(link_id) and is_binary(reference_id) and is_binary(status) and
             is_binary(signature) do
    verify_payment_link_signature(link_id, reference_id, status, signature, Config.key_secret())
  end

  @spec verify_payment_link_signature(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t()
        ) :: boolean()
  def verify_payment_link_signature(link_id, reference_id, status, signature, secret)
      when is_binary(link_id) and is_binary(reference_id) and is_binary(status) and
             is_binary(signature) and is_binary(secret) do
    verify("#{link_id}|#{reference_id}|#{status}", signature, secret)
  end

  def verify_payment_link_signature(_link_id, _reference_id, _status, _signature, _secret),
    do: false

  @doc """
  Verifies a webhook signature over the raw request body.

  Equivalent to `RazorpayEx.Webhook.verify/3`, provided here so callers can
  keep all signature checks in one place.
  """
  @spec verify_webhook_signature(String.t(), String.t(), String.t()) :: boolean()
  def verify_webhook_signature(body, signature, secret) do
    Webhook.verify(body, signature, secret)
  end

  defp verify(data, signature, secret) when is_binary(secret) do
    Signature.valid?(Signature.hmac_sha256(data, secret), signature)
  end

  defp verify(_data, _signature, _secret), do: false

  defp fetch_param(params, {string_key, atom_key}) when is_map(params) do
    case Map.fetch(params, string_key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(params, atom_key)
    end
  end

  defp fetch_param(params, {string_key, atom_key}) when is_list(params) do
    case List.keyfind(params, string_key, 0) do
      {_, value} -> {:ok, value}
      nil -> Keyword.fetch(params, atom_key)
    end
  end
end
