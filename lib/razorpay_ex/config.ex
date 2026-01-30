defmodule RazorpayEx.Config do
  @moduledoc """
  Configuration management for RazorpayEx client.

  This module handles configuration loading from application environment,
  environment variables, and provides convenience functions for setup.

  ## Configuration Sources

  Configuration is loaded in this order:

  1. Explicit configuration via `RazorpayEx.Config.set/1`
  2. Application environment (`config :razorpay_ex ...`)
  3. Environment variables
  4. Default values

  ## Examples

      # Configure via application config
      config :razorpay_ex
        key_id: "rzp_test_key_id",
        key_secret: "test_secret"

      # Configure programmatically
      RazorpayEx.Config.set(%{
        key_id: "rzp_test_key_id",
        key_secret: "test_secret"
      })

      # Setup OAuth
      RazorpayEx.Config.setup_oauth("oauth_token_123")

      # Setup Basic Auth
      RazorpayEx.Config.setup_basic_auth("key_id", "key_secret")
  """

  alias RazorpayEx.Constants

  @type t :: %__MODULE__{
          key_id: String.t() | nil,
          key_secret: String.t() | nil,
          access_token: String.t() | nil,
          auth_type: :basic | :oauth,
          custom_headers: map(),
          api_base_url: String.t(),
          auth_base_url: String.t(),
          timeout: integer(),
          enable_logging: boolean()
        }

  defstruct [
    :key_id,
    :key_secret,
    :access_token,
    :auth_type,
    :custom_headers,
    :api_base_url,
    :auth_base_url,
    :timeout,
    :enable_logging
  ]

  @default_timeout 30_000
  @default_api_base_url Constants.base_url()
  @default_auth_base_url Constants.auth_url()

  def custom_headers do
    Application.get_env(:razorpay_ex, :custom_headers, %{})
  end

  @doc """
  Returns the current configuration.
  """
  @spec get() :: t()
  def get do
    %__MODULE__{
      key_id: key_id(),
      key_secret: key_secret(),
      access_token: access_token(),
      auth_type: auth_type(),
      custom_headers: custom_headers(),
      api_base_url: api_base_url(),
      auth_base_url: auth_base_url(),
      timeout: timeout(),
      enable_logging: enable_logging()
    }
  end

  @doc """
  Sets configuration from a map.

  ## Examples

      RazorpayEx.Config.set(%{
        key_id: "rzp_test_key_id",
        key_secret: "test_secret",
        timeout: 60000
      })
  """
  @spec set(map()) :: :ok
  def set(config) when is_map(config) do
    Enum.each(config, fn {key, value} ->
      Application.put_env(:razorpay_ex, key, value)
    end)

    :ok
  end

  @doc """
  Configures OAuth authentication.

  ## Parameters

    - `access_token`: OAuth access token
    - `opts`: Additional options (custom_headers, timeout, etc.)

  ## Examples

      RazorpayEx.Config.setup_oauth("oauth_token_123")

      RazorpayEx.Config.setup_oauth("oauth_token_123", timeout: 60000)
  """
  @spec setup_oauth(String.t(), keyword()) :: :ok
  def setup_oauth(access_token, opts \\ []) do
    config =
      %{
        auth_type: :oauth,
        access_token: access_token
      }
      |> Map.merge(Enum.into(opts, %{}))

    set(config)
  end

  @doc """
  Configures basic authentication.

  ## Parameters

    - `key_id`: RazorpayEx key ID
    - `key_secret`: RazorpayEx key secret
    - `opts`: Additional options

  ## Examples

      RazorpayEx.Config.setup_basic_auth("rzp_test_key_id", "test_secret")

      RazorpayEx.Config.setup_basic_auth("key_id", "secret", timeout: 60000)
  """
  @spec setup_basic_auth(String.t(), String.t(), keyword()) :: :ok
  def setup_basic_auth(key_id, key_secret, opts \\ []) do
    config =
      %{
        auth_type: :basic,
        key_id: key_id,
        key_secret: key_secret
      }
      |> Map.merge(Enum.into(opts, %{}))

    set(config)
  end

  # Getters with fallbacks

  @doc """
  Returns the RazorpayEx key ID.
  """
  @spec key_id() :: String.t()
  def key_id do
    Application.get_env(:razorpay_ex, :key_id) ||
      System.get_env("RAZORPAY_KEY_ID") ||
      raise """
      RazorpayEx key_id not configured.
      Set it in config :razorpay_ex key_id: "your_key_id"
      or set RAZORPAY_KEY_ID environment variable.
      """
  end

  @doc """
  Returns the RazorpayEx key secret.
  """
  @spec key_secret() :: String.t()
  def key_secret do
    Application.get_env(:razorpay_ex, :key_secret) ||
      System.get_env("RAZORPAY_KEY_SECRET") ||
      raise """
      RazorpayEx key_secret not configured.
      Set it in config :razorpay_ex key_secret: "your_key_secret"
      or set RAZORPAY_KEY_SECRET environment variable.
      """
  end

  @doc """
  Returns the OAuth access token.
  """
  @spec access_token() :: String.t() | nil
  def access_token do
    Application.get_env(:razorpay_ex, :access_token) ||
      System.get_env("RAZORPAY_ACCESS_TOKEN")
  end

  @doc """
  Returns the authentication type.
  """
  @spec auth_type() :: :basic | :oauth
  def auth_type do
    case Application.get_env(:razorpay_ex, :auth_type) || System.get_env("RAZORPAY_AUTH_TYPE") do
      "oauth" -> :oauth
      :oauth -> :oauth
      _ -> :basic
    end
  end

  @doc """
  Returns custom headers.
  """
  @spec custom_headers() :: map()
  def custom_headers do
    Application.get_env(:razorpay_ex, :custom_headers) || %{}
  end

  @doc """
  Returns the API base URL.
  """
  @spec api_base_url() :: String.t()
  def api_base_url do
    Application.get_env(:razorpay_ex, :api_base_url) || @default_api_base_url
  end

  @doc """
  Returns the auth base URL.
  """
  @spec auth_base_url() :: String.t()
  def auth_base_url do
    Application.get_env(:razorpay_ex, :auth_base_url) || @default_auth_base_url
  end

  @doc """
  Returns the request timeout.
  """
  @spec timeout() :: integer()
  def timeout do
    Application.get_env(:razorpay_ex, :timeout) || @default_timeout
  end

  @doc """
  Returns whether logging is enabled.
  """
  @spec enable_logging() :: boolean()
  def enable_logging do
    Application.get_env(:razorpay_ex, :enable_logging, false)
  end
end
