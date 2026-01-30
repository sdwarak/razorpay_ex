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

  alias RazorpayEx.{Config, Constants, Error, Entity, HttpClient}

  @http_client Application.get_env(:razorpay_ex, :http_client, RazorpayEx.HttpAdapter)

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
  """ # This needs to be updated to use runtime configuration


  defp http_client do
    Application.get_env(:razorpay_ex, :http_client, RazorpayEx.HttpAdapter)
  end

  @spec request(http_method, String.t(), map(), request_options()) :: response()
  def request(method, path, data \\ %{}, opts \\ []) do
    url = build_url(path, opts)
    headers = build_headers(opts)
    body = encode_body(data, method)
    query_params = Keyword.get(opts, :params, %{})

    options = [
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      recv_timeout: Keyword.get(opts, :timeout, @default_timeout),
      params: query_params
    ]

    # Use http_client/0 function instead of @http_client
    case http_client().request(method, url, body, headers, options) do
      {:ok, %{status_code: status, body: body, headers: _headers}} ->
        handle_response(status, body)

      {:error, error} ->
        {:error, Error.new(:network_error, "HTTP error: #{inspect(error.reason)}")}
    end
  end

  @doc """
  Makes a raw HTTP request without automatic entity transformation.

  This is useful when you need access to the raw HTTP response.

  ## Examples

      {:ok, response} =
        RazorpayEx.Client.raw_request(:get, "/payments/pay_123")
  """
   @spec raw_request(http_method, String.t(), map(), request_options()) ::
    {:ok, map()} | {:error, Error.t()}
  def raw_request(method, path, data \\ %{}, opts \\ []) do
    url = build_url(path, opts)
    headers = build_headers(opts)
    body = encode_body(data, method)
    query_params = Keyword.get(opts, :params, %{})

    options = [
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      recv_timeout: Keyword.get(opts, :timeout, @default_timeout),
      params: query_params
    ]

    # Use http_client/0 function instead of @http_client
    case http_client().request(method, url, body, headers, options) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, Error.new(:network_error, "HTTP error: #{inspect(error.reason)}")}
    end
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
    config_headers = Config.custom_headers()
    auth_header = build_auth_header()

    # Convert config headers map to list of tuples with lowercased keys
    config_header_list =
      Enum.map(config_headers, fn {k, v} ->
        {String.downcase(to_string(k)), to_string(v)}
      end)

    # Convert custom_headers to have string keys
    custom_headers_normalized =
      Enum.map(custom_headers, fn {k, v} ->
        {String.downcase(to_string(k)), to_string(v)}
      end)

    # Start with default headers
    @default_headers
    |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
    |> Kernel.++(config_header_list)
    |> Kernel.++(custom_headers_normalized)
    |> Kernel.++([{"authorization", auth_header}])
    |> Enum.uniq_by(fn {k, _v} -> k end)
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

  defp handle_response(status, body) do
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
    module_name = entity_type
      |> String.split("_")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join("")

    try do
      module = Module.safe_concat([RazorpayEx, module_name])
      # Convert string keys to atoms for struct creation
      atom_data = for {key, val} <- data, into: %{}, do: {String.to_atom(key), val}
      struct(module, atom_data)
    rescue
      ArgumentError ->
        # Fall back to Entity if specific module doesn't exist
        atom_data = for {key, val} <- data, into: %{}, do: {String.to_atom(key), val}
        struct(Entity, atom_data)
    end
  end

  defp transform_entity(data) do
    data
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

  defp parse_error_response("", status), do: parse_error_response("{}", status)

  defp parse_error_response(body, status) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        {:error, Error.from_map(error, status)}
      {:ok, parsed} ->
        # If there's no "error" key, but it's an error status, create generic error
        {:error, Error.new("BAD_REQUEST_ERROR", Map.get(parsed, "description", "Authentication failed"), status, body)}
      {:error, _} ->
        {:error, Error.new("HTTP_#{status}", "HTTP Error #{status}: #{body}", status)}
    end
  end
end
