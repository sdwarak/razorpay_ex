# lib/razorpay_ex/http_client.ex
defmodule RazorpayEx.HttpClient do
  @moduledoc """
  HTTP client behaviour for making HTTP requests.
  """

  @type method :: :get | :post | :put | :patch | :delete
  @type url :: String.t()
  @type body :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type options :: keyword()

  @type response ::
    {:ok, %{status_code: integer(), body: String.t(), headers: list()}} |
    {:error, %{reason: any()}}

  @callback request(method, url, body, headers, options) :: response
end
