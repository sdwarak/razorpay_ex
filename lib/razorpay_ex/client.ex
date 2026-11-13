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

  require Logger

  @default_retry_delay 100
  @max_retry_delay 5_000

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

    transport = %{
      method: method,
      url: url,
      body: body,
      headers: headers,
      options: [timeout: timeout, recv_timeout: timeout]
    }

    transport
    |> attempt(Keyword.get(opts, :retry, 0), Keyword.get(opts, :retry_delay, @default_retry_delay))
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, _reason} -> {:error, Error.new(:network_error, "HTTP request failed")}
    end
  end

  # Private functions

  # A request is retried only when the caller opted in with `retry: n`. Retrying
  # a non-idempotent request without an idempotency key can duplicate work, so
  # the default stays at zero.
  defp attempt(transport, retries_left, delay) when retries_left >= 0 do
    started = System.monotonic_time(:millisecond)
    result = perform(transport)
    log_request(transport, result, System.monotonic_time(:millisecond) - started)

    if retries_left > 0 and retryable?(result) do
      Process.sleep(retry_delay(result, delay))
      attempt(transport, retries_left - 1, min(delay * 2, @max_retry_delay))
    else
      result
    end
  end

  defp perform(transport) do
    http_client().request(
      transport.method,
      transport.url,
      transport.body,
      transport.headers,
      transport.options
    )
  end

  defp retryable?({:error, _reason}), do: true
  defp retryable?({:ok, %{status_code: status}}), do: status in [408, 409, 429] or status >= 500
  defp retryable?(_result), do: false

  # Honour `retry-after` when the server sends it; otherwise back off
  # exponentially with a little jitter so parallel callers do not sync up.
  defp retry_delay({:ok, %{headers: headers}}, fallback) when is_list(headers) do
    case List.keyfind(headers, "retry-after", 0) do
      {_key, value} when is_binary(value) ->
        case Integer.parse(value) do
          {seconds, ""} -> min(seconds * 1_000, @max_retry_delay)
          _ -> fallback + jitter()
        end

      _ ->
        fallback + jitter()
    end
  end

  defp retry_delay(_result, fallback), do: fallback + jitter()

  defp jitter, do: :rand.uniform(50)

  # Logs method, path and outcome only. Query strings, headers and bodies are
  # deliberately excluded: they can carry customer data and credentials.
  defp log_request(transport, result, duration_ms) do
    if Config.enable_logging() do
      path = transport.url |> URI.parse() |> Map.get(:path)

      outcome =
        case result do
          {:ok, %{status_code: status}} -> Integer.to_string(status)
          {:error, reason} -> "error #{inspect(reason)}"
        end

      method = transport.method |> to_string() |> String.upcase()

      Logger.debug(fn ->
        "razorpay_ex #{method} #{path} -> #{outcome} (#{duration_ms}ms)"
      end)
    end

    :ok
  end

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
