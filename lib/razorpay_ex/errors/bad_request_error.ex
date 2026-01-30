defmodule RazorpayEx.Errors.BadRequestError do
  @moduledoc """
  Bad Request Error (400).

  Similar to Ruby SDK's BadRequestError.
  """
  defexception [:message, :code, :description, :field, :http_status_code]

  @impl true
  def exception(attrs) do
    %__MODULE__{
      message: "Bad Request: #{attrs[:description]}",
      code: attrs[:code] || "BAD_REQUEST_ERROR",
      description: attrs[:description],
      field: attrs[:field],
      http_status_code: attrs[:http_status_code] || 400
    }
  end
end
