defmodule RazorpayEx.Errors.GatewayError do
  @moduledoc """
  Gateway Error (502).

  Raise it when you want a gateway-side failure to surface as an exception:

      raise RazorpayEx.Errors.GatewayError, description: "Upstream unavailable"

  The client itself returns `%RazorpayEx.Error{}` tuples rather than raising;
  this module is provided for callers that prefer exceptions.
  """
  defexception [:message, :code, :description, :http_status_code]

  @impl true
  def exception(attrs) do
    %__MODULE__{
      message: "Gateway Error: #{attrs[:description]}",
      code: attrs[:code] || "GATEWAY_ERROR",
      description: attrs[:description],
      http_status_code: attrs[:http_status_code] || 502
    }
  end
end
