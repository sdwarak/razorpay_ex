defmodule RazorpayEx.Request do
  @moduledoc """
  Request module for making HTTP requests to Razorpay API.

  This is the core HTTP client, similar to Ruby SDK's Request class.
  """

  alias RazorpayEx.{Config, Constants, Error, Entity}

  @type http_method :: :get | :post | :put | :patch | :delete
  @type response :: {:ok, map() | list()} | {:error, Error.t()}

  @doc """
  Makes a raw HTTP request to Razorpay API.

  Similar to Ruby SDK's Request#raw_request method.
  """
  @spec raw_request(http_method, String.t(), map(), keyword()) ::
          {:ok, HTTPoison.Response.t()} | {:error, Error.t()}
  def raw_request(method, path, data \\ %{}, opts \\ []) do
    url = build_url(path, opts)
    headers = build_headers(opts)
    body = prepare_body(method, data)
    query_params = Keyword.get(opts, :params, %{})

    options = [
      timeout: Config.timeout(),
      recv_timeout: Config.timeout(),
      params: query_params
    ]

    case HTTPoison.request(method, url, body, headers, options) do
      {:ok, response} ->
        {:ok, response}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, Error.new(:network_error, "HTTP error: #{inspect(reason)}")}
    end
  end

  @doc """
  Makes a request and parses the response.

  Similar to Ruby SDK's Request#request method.
  """
  @spec request(http_method, String.t(), map(), keyword()) :: response()
  def request(method, path, data \\ %{}, opts \\ []) do
    with {:ok, response} <- raw_request(method, path, data, opts) do
      handle_response(response)
    end
  end

  @doc """
  Fetches an entity by ID.

  Similar to Ruby SDK's Request#fetch method.
  """
  @spec fetch(atom(), String.t(), keyword()) :: response()
  def fetch(resource_type, id, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}/#{id}"
    request(:get, path, %{}, opts)
  end

  @doc """
  Lists all entities with optional filters.

  Similar to Ruby SDK's Request#all method.
  """
  @spec all(atom(), map(), keyword()) :: response()
  def all(resource_type, params \\ %{}, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}"
    request(:get, path, %{}, Keyword.put(opts, :params, params))
  end

  @doc """
  Creates a new entity.

  Similar to Ruby SDK's Request#create method.
  """
  @spec create(atom(), map(), keyword()) :: response()
  def create(resource_type, data, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}"
    request(:post, path, data, opts)
  end

  @doc """
  Updates an entity.

  Similar to Ruby SDK's Request#put method.
  """
  @spec update(atom(), String.t(), map(), keyword()) :: response()
  def update(resource_type, id, data, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}/#{id}"
    request(:put, path, data, opts)
  end

  @doc """
  Patches an entity (partial update).

  Similar to Ruby SDK's Request#patch method.
  """
  @spec patch(atom(), String.t(), map(), keyword()) :: response()
  def patch(resource_type, id, data, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}/#{id}"
    request(:patch, path, data, opts)
  end

  @doc """
  Deletes an entity.

  Similar to Ruby SDK's Request#delete method.
  """
  @spec delete(atom(), String.t(), keyword()) :: response()
  def delete(resource_type, id, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}/#{id}"
    request(:delete, path, %{}, opts)
  end

  @doc """
  Makes a GET request to a specific URL.

  Similar to Ruby SDK's Request#get method.
  """
  @spec get_url(atom(), String.t(), map(), keyword()) :: response()
  def get_url(resource_type, url, data \\ %{}, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}/#{url}"
    request(:get, path, data, opts)
  end

  @doc """
  Makes a POST request to a specific URL.

  Similar to Ruby SDK's Request#post method.
  """
  @spec post_url(atom(), String.t(), map(), keyword()) :: response()
  def post_url(resource_type, url, data \\ %{}, opts \\ []) do
    endpoint = Constants.endpoint_path(resource_type)
    path = "/#{Constants.api_version()}/#{endpoint}/#{url}"
    request(:post, path, data, opts)
  end

  # Private functions

  defp build_url(path, opts) do
    base_url =
      case Keyword.get(opts, :host, :api) do
        :auth -> Constants.auth_url()
        _ -> Config.api_url()
      end
    base_url <> path
  end

  defp build_headers(opts) do
    custom_headers = Config.get_headers()

    auth_header =
      case Config.get_auth() do
        {:basic, key_id, key_secret} ->
          auth = Base.encode64("#{key_id}:#{key_secret}")
          {"Authorization", "Basic #{auth}"}
        {:oauth, token} ->
          {"Authorization", "Bearer #{token}"}
      end

    default_headers = %{
      "Content-Type" => "application/json",
      "User-Agent" => Constants.user_agent()
    }

    default_headers
    |> Map.merge(custom_headers)
    |> Map.to_list()
    |> List.insert_at(0, auth_header)
  end

  defp prepare_body(:get, _data), do: ""
  defp prepare_body(_method, data) when data == %{}, do: ""
  defp prepare_body(_method, data), do: Jason.encode!(data)

  defp handle_response(%HTTPoison.Response{status_code: status, body: body}) do
    cond do
      status >= 200 and status < 300 ->
        parse_success_response(body)
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
      _ ->
        {:error, Error.new("HTTP_#{status}", "HTTP Error #{status}: #{inspect(body)}", status)}
    end
  end

  defp transform_response(data) when is_list(data) do
    Enum.map(data, &Entity.build/1)
  end

  defp transform_response(data) do
    Entity.build(data)
  end
end
