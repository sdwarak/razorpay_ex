defmodule RazorpayEx.HttpAdapter do
  @moduledoc """
  HTTP adapter that implements HttpClient behaviour using HTTPoison.
  """

  @behaviour RazorpayEx.HttpClient

  @impl true
  def request(method, url, body, headers, options) do
    HTTPoison.request(method, url, body, headers, options)
    |> normalize_response()
  end

  defp normalize_response({:ok, %HTTPoison.Response{} = response}) do
    {:ok, %{
      status_code: response.status_code,
      body: response.body,
      headers: response.headers
    }}
  end

  defp normalize_response({:error, %HTTPoison.Error{} = error}) do
    {:error, %{reason: error.reason}}
  end
end
