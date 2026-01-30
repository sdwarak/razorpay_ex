defmodule RazorpayEx.Client do
  @moduledoc """
  HTTP client for making requests to the Razorpay API.

  This module handles all HTTP communication with Razorpay's servers,
  including authentication, request formatting, and response parsing.

  ## Usage

      # Using the default client
      {:ok, response} = RazorpayEx.Client.request(:get, "/payments/pay_123")

      # With custom options
      {:ok, response} = RazorpayEx.Client.request(:post, "/orders", %{amount: 50000}, timeout: 60000)
  """

  alias RazorpayEx.{Config, Constants, Error, Entity}

  @default_timeout 30_000
  @default_headers [
    {"Content-Type", "application/json"},
    {"User-Agent", "razorpay_ex/#{RazorpayEx.version()}"}
  ]

  @type http_method :: :get | :post | :put | :patch | :delete
  @type request_options :: keyword()
  @type response :: {:ok, map() | list()} | {:error, Error.t()}

  @doc """
  Makes an HTTP request to the RazorpayEx API.

  ## Parameters

    - `method`: HTTP method (`:get`, `:post`, `:put`, `:patch`, `:delete`)
    - `path`: API endpoint path
    - `data`: Request body data (for POST, PUT, PATCH requests)
    - `opts`: Additional options (timeout, headers, etc.)

  ## Options

    - `:timeout` - Request timeout in milliseconds (default: 30000)
    - `:headers` - Additional HTTP headers
    - `:params` - Query parameters (for GET requests)
    - `:host` - API host (`:api` or `:auth`)

  ## Examples

      # GET request
      {:ok, payments} = RazorpayEx.Client.request(:get, "/payments")

      # POST request
      {:ok, order} = RazorpayEx.Client.request(:post, "/orders", %{amount: 50000})

      # With query parameters
      {:ok, payments} = RazorpayEx.Client.request(:get, "/payments", %{}, params: %{count: 10})
  """
  @spec request(http_method, String.t(), map(), request_options()) :: response()
  def request(method, path, data \\ %{}, opts \\ []) do
    client_opts = build_client_opts(opts)
    url = build_url(path, opts)
    headers = build_headers(opts)
    body = encode_body(data, method)

    options = [
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      recv_timeout: Keyword.get(opts, :timeout, @default_timeout),
      ssl: [
        versions: [:"tlsv1.2"],
        verify: :verify_peer,
        cacertfile: :certifi.cacertfile()
      ]
    ]

    case HTTPoison.request(method, url, body, headers, options) do
      {:ok, response} ->
        handle_response(response)

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, Error.new(:network_error, "HTTPoison error: #{inspect(reason)}")}
    end
  end

  @doc """
  Makes a raw HTTP request without automatic entity transformation.

  This is useful when you need access to the raw HTTP response.

  ## Examples

      {:ok, %HTTPoison.Response{} = response} =
        RazorpayEx.Client.raw_request(:get, "/payments/pay_123")
  """
  @spec raw_request(http_method, String.t(), map(), request_options()) ::
          {:ok, HTTPoison.Response.t()} | {:error, Error.t()}
  def raw_request(method, path, data \\ %{}, opts \\ []) do
    client_opts = build_client_opts(opts)
    url = build_url(path, opts)
    headers = build_headers(opts)
    body = encode_body(data, method)

    options = [
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      recv_timeout: Keyword.get(opts, :timeout, @default_timeout)
    ]

    HTTPoison.request(method, url, body, headers, options)
  end

  # Private functions

  defp build_url(path, opts) do
    base_url =
      case Keyword.get(opts, :host, :api) do
        :auth -> Config.auth_base_url()
        _ -> Config.api_base_url()
      end

    base_url <> path
  end

  defp build_headers(opts) do
    custom_headers = Keyword.get(opts, :headers, [])
    auth_header = build_auth_header()

    @default_headers
    |> Keyword.merge(custom_headers)
    |> Keyword.put_new(:authorization, auth_header)
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp build_auth_header do
    case Config.auth_type() do
      :oauth ->
        "Bearer #{Config.access_token()}"

      _ ->
        auth = Base.encode64("#{Config.key_id()}:#{Config.key_secret()}")
        "Basic #{auth}"
    end
  end

  defp encode_body(data, method) when method in [:post, :put, :patch] and data != %{} do
    Jason.encode!(data)
  end

  defp encode_body(_, _), do: ""

  defp handle_response(%HTTPoison.Response{status_code: status, body: body}) do
    cond do
      status >= 200 && status < 300 ->
        parse_success_response(body)

      body == "" ->
        {:error, Error.new("HTTP_#{status}", "Empty response body", status)}

      true ->
        parse_error_response(body, status)
    end
  end

  defp parse_success_response(""), do: {:ok, %{}}

  defp parse_success_response(body) do
    case Jason.decode(body) do
      {:ok, parsed} ->
        {:ok, transform_response(parsed)}

      {:error, error} ->
        {:error, Error.new(:invalid_json, "Failed to parse JSON: #{inspect(error)}")}
    end
  end

  defp parse_error_response(body, status) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        {:error, Error.from_map(error, status)}

      {:ok, _} ->
        {:error, Error.new("HTTP_#{status}", "HTTP Error #{status}", status)}

      {:error, _} ->
        {:error, Error.new("HTTP_#{status}", "HTTP Error #{status}: #{body}", status)}
    end
  end

  defp transform_response(response) when is_list(response) do
    Enum.map(response, &transform_entity/1)
  end

  defp transform_response(response) when is_map(response) do
    transform_entity(response)
  end

  defp transform_response(response), do: response

  defp transform_entity(%{"entity" => entity_type} = data) do
    module_name =
      entity_type
      |> String.split("_")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join("")

    try do
      module = Module.safe_concat([RazorpayEx, module_name])
      struct(module, data)
    rescue
      ArgumentError ->
        # Fall back to Entity if specific module doesn't exist
        struct(Entity, data)
    end
  end

  defp transform_entity(data) do
    data
  end

  defp build_client_opts(opts) do
    Keyword.take(opts, [:timeout, :headers, :params, :host])
  end
end
