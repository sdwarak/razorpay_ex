defmodule RazorpayEx.Signature do
  @moduledoc false

  # Shared HMAC helpers. Kept private to the library; use
  # `RazorpayEx.Utility` or `RazorpayEx.Webhook` for verification.

  @doc """
  Returns the lowercase hex HMAC-SHA256 of `data` keyed with `secret`.
  """
  @spec hmac_sha256(iodata(), String.t()) :: String.t()
  def hmac_sha256(data, secret) when is_binary(secret) do
    :crypto.mac(:hmac, :sha256, secret, data)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Constant-time comparison of two signatures.

  Both values are HMACed with a fixed key and the resulting digests are
  compared, so the comparison time does not depend on where the inputs differ.
  """
  @spec valid?(String.t(), String.t() | nil) :: boolean()
  def valid?(_expected, nil), do: false

  def valid?(expected, provided) when is_binary(expected) and is_binary(provided) do
    byte_size(expected) == byte_size(provided) and
      hmac_sha256(expected, "razorpay_ex.secure_compare") ==
        hmac_sha256(provided, "razorpay_ex.secure_compare")
  end

  def valid?(_expected, _provided), do: false
end
