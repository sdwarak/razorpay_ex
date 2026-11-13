defmodule RazorpayEx.Request do
  @moduledoc """
  Low-level request helpers.

  This module predates `RazorpayEx.Client` and now delegates to it, so both
  paths share one implementation and one set of response semantics.

  Prefer `RazorpayEx.Client` or the resource modules (`RazorpayEx.Payment`,
  `RazorpayEx.Order`, ...) for new code.

  ## Response shapes

    * `request/4` returns parsed entities (`{:ok, struct() | [struct()]}`)
    * `raw_request/4` returns the raw transport response
      (`{:ok, %{status_code: integer(), body: String.t(), headers: list()}}`)
  """

  alias RazorpayEx.{Client, Constants}

  @type http_method :: :get | :post | :put | :patch | :delete

  @doc """
  Makes a raw HTTP request to the Razorpay API.

  The response body is returned verbatim, without JSON decoding or entity
  casting.
  """
  @spec raw_request(http_method(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, RazorpayEx.Error.t()}
  def raw_request(method, path, data \\ %{}, opts \\ []) do
    Client.raw_request(method, path, data, opts)
  end

  @doc """
  Makes a request and parses the response into entities.
  """
  @spec request(http_method(), String.t(), map(), keyword()) :: Client.response()
  def request(method, path, data \\ %{}, opts \\ []) do
    Client.request(method, path, data, opts)
  end

  @doc """
  Fetches an entity by ID.
  """
  @spec fetch(atom(), String.t(), keyword()) :: Client.response()
  def fetch(resource_type, id, opts \\ []) do
    request(:get, resource_path(resource_type, id), %{}, opts)
  end

  @doc """
  Lists entities, optionally filtered.
  """
  @spec all(atom(), map(), keyword()) :: Client.response()
  def all(resource_type, params \\ %{}, opts \\ []) do
    request(:get, resource_path(resource_type), %{}, Keyword.put(opts, :params, params))
  end

  @doc """
  Creates an entity.
  """
  @spec create(atom(), map(), keyword()) :: Client.response()
  def create(resource_type, data, opts \\ []) do
    request(:post, resource_path(resource_type), data, opts)
  end

  @doc """
  Updates an entity.
  """
  @spec update(atom(), String.t(), map(), keyword()) :: Client.response()
  def update(resource_type, id, data, opts \\ []) do
    request(:put, resource_path(resource_type, id), data, opts)
  end

  @doc """
  Patches an entity (partial update).
  """
  @spec patch(atom(), String.t(), map(), keyword()) :: Client.response()
  def patch(resource_type, id, data, opts \\ []) do
    request(:patch, resource_path(resource_type, id), data, opts)
  end

  @doc """
  Deletes an entity.
  """
  @spec delete(atom(), String.t(), keyword()) :: Client.response()
  def delete(resource_type, id, opts \\ []) do
    request(:delete, resource_path(resource_type, id), %{}, opts)
  end

  @doc """
  Makes a GET request against a sub-path of a resource.
  """
  @spec get_url(atom(), String.t(), map(), keyword()) :: Client.response()
  def get_url(resource_type, url, data \\ %{}, opts \\ []) do
    request(:get, resource_path(resource_type, url), data, opts)
  end

  @doc """
  Makes a POST request against a sub-path of a resource.
  """
  @spec post_url(atom(), String.t(), map(), keyword()) :: Client.response()
  def post_url(resource_type, url, data \\ %{}, opts \\ []) do
    request(:post, resource_path(resource_type, url), data, opts)
  end

  # The base URL already contains the API version, so paths are relative to it.
  defp resource_path(resource_type, suffix \\ nil) do
    path = "/" <> Constants.endpoint_path(resource_type)

    if suffix, do: path <> "/" <> to_string(suffix), else: path
  end
end
