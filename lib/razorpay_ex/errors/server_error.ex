# lib/razorpay_ex/errors/server_error.ex
defmodule RazorpayEx.Errors.ServerError do
  @moduledoc """
  Server Error (500).

  Similar to Ruby SDK's ServerError.
  """
  defexception [:message, :code, :description, :http_status_code]

  @impl true
  def exception(attrs) do
    %__MODULE__{
      message: "Server Error: #{attrs[:description]}",
      code: attrs[:code] || "SERVER_ERROR",
      description: attrs[:description],
      http_status_code: attrs[:http_status_code] || 500
    }
  end
end
