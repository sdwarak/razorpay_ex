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

  alias RazorpayEx.{Config, Entity, Error, Query}

  # Built at runtime: the application version is not available while the
  # project itself is being compiled.
  defp default_headers do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", "razorpay_ex/#{RazorpayEx.version()}"}
    ]
  end

  @type http_method :: :get | :post | :put | :patch | :delete
  @type request_options :: keyword()
  @type response :: {:ok, struct() | list() | map()} | {:error, Error.t()}

  defp http_client do
    Application.get_env(:razorpay_ex, :http_client, RazorpayEx.HttpAdapter)
  end

  @doc """
  Makes an HTTP request to the RazorpayEx API.

  ## Parameters

    - `method`: HTTP method (`:get`, `:post`, `:put`, `:patch`, `:delete`)
    - `path`: API endpoint path
    - `data`: Request body data (for POST, PUT, PATCH requests)
    - `opts`: Additional options (timeout, headers, etc.)

  ## Options

    - `:timeout` - Request timeout in milliseconds. Defaults to the
      `:timeout` application setting, which is 30 seconds when unset
    - `:headers` - Additional HTTP headers
    - `:params` - Query parameters. List values are sent as repeated `key[]`
      parameters, and `:expand` is always sent as `expand[]`
    - `:host` - API host (`:api` or `:auth`)

  ## Examples

      # GET request
      {:ok, payments} = RazorpayEx.Client.request(:get, "/payments")

      # POST request
      {:ok, order} = RazorpayEx.Client.request(:post, "/orders", %{amount: 50000})

      # With query parameters
      {:ok, payments} = RazorpayEx.Client.request(:get, "/payments", %{}, params: %{count: 10})

      # Expanding nested entities
      {:ok, payment} = RazorpayEx.Client.request(:get, "/payments/pay_123", %{}, params: %{expand: ["card"]})
  """
  @spec request(http_method, String.t(), map(), request_options()) :: response()
  def request(method, path, data \\ %{}, opts \\ []) do
    case raw_request(method, path, data, opts) do
      {:ok, %{status_code: status, body: body}} ->
        handle_response(status, body)

      {:error, %Error{} = error} ->
        {:error, error}
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
    url = build_url(path, opts) |> append_query(Keyword.get(opts, :params, %{}))
    headers = build_headers(opts)
    body = encode_body(data, method)

    timeout = Keyword.get(opts, :timeout, Config.timeout())
    options = [timeout: timeout, recv_timeout: timeout]

    case http_client().request(method, url, body, headers, options) do
      {:ok, response} ->
        {:ok, response}

      {:error, _error} ->
        {:error, Error.new(:network_error, "HTTP request failed")}
    end
  end

  # Private functions

  defp build_url(path, opts) do
    base_url =
      case Keyword.get(opts, :host, :api) do
        :auth -> Config.auth_base_url()
        _ -> Config.api_base_url()
      end

    base_url
    |> String.trim_trailing("/")
    |> Kernel.<>(normalize_path(path))
  end

  defp normalize_path("/" <> _rest = path), do: path
  defp normalize_path(path), do: "/" <> path

  defp append_query(url, params) do
    case Query.encode(params) do
      "" -> url
      query -> url <> if(String.contains?(url, "?"), do: "&", else: "?") <> query
    end
  end

  defp build_headers(opts) do
    custom_headers = Keyword.get(opts, :headers, [])
    config_headers = Config.custom_headers()
    auth_header = build_auth_header()

    normalize = fn headers ->
      Enum.map(headers, fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
    end

    # Later headers win: request headers override configured headers, which
    # override the defaults. The authorization header is always applied last.
    (normalize.(default_headers()) ++
       normalize.(config_headers) ++
       normalize.(custom_headers) ++
       [{"authorization", auth_header}])
    |> Enum.reverse()
    |> Enum.uniq_by(fn {k, _v} -> k end)
    |> Enum.reverse()
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

      {:error, _error} ->
        {:error, Error.new(:invalid_json, "Failed to parse response body")}
    end
  end

  defp parse_error_response(body, status) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        {:error, Error.from_map(error, status)}

      {:ok, _} ->
        {:error, Error.new("HTTP_#{status}", "HTTP Error #{status}", status)}

      {:error, _} ->
        {:error, Error.new("HTTP_#{status}", "HTTP Error #{status}", status)}
    end
  end

  # Razorpay list endpoints return `{"entity": "collection", "count": N, "items": [...]}`.
  # The caller gets the list of items; `count` is always the number of items
  # returned for the current page, so it carries no extra information.
  defp transform_response(%{"entity" => "collection"} = collection) do
    collection
    |> Map.get("items", [])
    |> List.wrap()
    |> Enum.map(&transform_entity/1)
  end

  defp transform_response(response) when is_list(response) do
    Enum.map(response, &transform_entity/1)
  end

  defp transform_response(response) when is_map(response) do
    transform_entity(response)
  end

  defp transform_response(response), do: response

  defp transform_entity(%{"entity" => entity_type} = data) when is_binary(entity_type) do
    Entity.cast(Entity.module_for(entity_type), data)
  end

  defp transform_entity(data), do: data
end
