defmodule RazorpayEx.Constants do
  @moduledoc """
  Constants for RazorpayEx - mirrors constants from Ruby SDK.
  """

  # API Endpoints (from Ruby SDK's lib/razorpay/constants.rb)
  @api_host "https://api.razorpay.com"
  @auth_host "https://auth.razorpay.com"

  # Base URLs
  @base_url "#{@api_host}/v1"
  @auth_url "#{@auth_host}/v2"

  # Test URL (similar to Ruby SDK's TEST_URL)
  @test_url "#{@base_url}/payments"

  # API Versions
  @api_version "v1"

  # Authentication Types
  @auth_basic :basic
  @auth_oauth :oauth

  # HTTP Timeout (default 30 seconds)
  @default_timeout 30_000

  # Webhook Signature Header
  @webhook_signature_header "x-razorpay-signature"

  # API Entity Names (from Ruby SDK supported resources)
  @entity_names %{
    account: "account",
    customer: "customer",
    token: "token",
    order: "order",
    payment: "payment",
    settlement: "settlement",
    fund: "fund",
    refund: "refund",
    invoice: "invoice",
    plan: "plan",
    item: "item",
    subscription: "subscription",
    addon: "addon",
    payment_link: "payment_link",
    product_configuration: "product_configuration",
    smart_collect: "smart_collect",
    stakeholder: "stakeholder",
    transfer: "transfer",
    qr_code: "qr_code",
    emandate: "emandate",
    card: "card",
    paper_nach: "paper_nach",
    upi: "upi",
    dispute: "dispute",
    document: "document"
  }

  # Endpoint collection names. Listed explicitly rather than pluralized at
  # runtime: spelling out the exceptions (`merchant`, `upi`, `paper_nach`)
  # keeps the mapping correct without pulling in an inflection dependency.
  @endpoint_paths %{
    account: "accounts",
    customer: "customers",
    token: "tokens",
    order: "orders",
    payment: "payments",
    settlement: "settlements",
    fund: "funds",
    refund: "refunds",
    invoice: "invoices",
    plan: "plans",
    item: "items",
    subscription: "subscriptions",
    addon: "addons",
    payment_link: "payment_links",
    product_configuration: "product_configurations",
    smart_collect: "virtual_accounts",
    virtual_account: "virtual_accounts",
    stakeholder: "stakeholders",
    transfer: "transfers",
    qr_code: "qr_codes",
    emandate: "emandates",
    card: "cards",
    paper_nach: "paper_nachs",
    upi: "upi",
    dispute: "disputes",
    document: "documents"
  }

  @doc """
  Returns the API host URL.
  """
  @spec api_host() :: String.t()
  def api_host, do: @api_host

  @doc """
  Returns the auth host URL.
  """
  @spec auth_host() :: String.t()
  def auth_host, do: @auth_host

  @doc """
  Returns the base API URL (v1).
  """
  @spec base_url() :: String.t()
  def base_url, do: @base_url

  @doc """
  Returns the auth API URL (v2).
  """
  @spec auth_url() :: String.t()
  def auth_url, do: @auth_url

  @doc """
  Returns the test URL for connectivity checks.
  """
  @spec test_url() :: String.t()
  def test_url, do: @test_url

  @doc """
  Returns the API version.
  """
  @spec api_version() :: String.t()
  def api_version, do: @api_version

  @doc """
  Returns basic authentication type.
  """
  @spec auth_basic() :: atom()
  def auth_basic, do: @auth_basic

  @doc """
  Returns OAuth authentication type.
  """
  @spec auth_oauth() :: atom()
  def auth_oauth, do: @auth_oauth

  @doc """
  Returns default timeout in milliseconds.
  """
  @spec default_timeout() :: integer()
  def default_timeout, do: @default_timeout

  @doc """
  Returns the user agent string.

  Built at runtime so it always carries the loaded application version.
  """
  @spec user_agent() :: String.t()
  def user_agent, do: "razorpay-ex/#{RazorpayEx.version()}"

  @doc """
  Returns the webhook signature header name.
  """
  @spec webhook_signature_header() :: String.t()
  def webhook_signature_header, do: @webhook_signature_header

  @doc """
  Returns entity name for a given resource type.

  ## Examples

      RazorpayEx.Constants.entity_name(:payment) # "payment"
      RazorpayEx.Constants.entity_name(:order)   # "order"
  """
  @spec entity_name(atom()) :: String.t()
  def entity_name(resource) do
    Map.get(@entity_names, resource) || to_string(resource)
  end

  @doc """
  Returns all supported entity names.
  """
  @spec entity_names() :: map()
  def entity_names, do: @entity_names

  @doc """
  Returns the pluralized entity name for API endpoints.

  ## Examples

      RazorpayEx.Constants.endpoint_path(:payment)   # "payments"
      RazorpayEx.Constants.endpoint_path(:customer)  # "customers"
  """
  @spec endpoint_path(atom()) :: String.t()
  def endpoint_path(resource) do
    Map.get(@endpoint_paths, resource) || pluralize(entity_name(resource))
  end

  defp pluralize(name) do
    cond do
      String.ends_with?(name, "s") -> name
      String.ends_with?(name, "y") -> String.replace_suffix(name, "y", "ies")
      true -> name <> "s"
    end
  end
end
