defmodule RazorpayEx do
  @moduledoc """
  Razorpay Elixir SDK - Unofficial Elixir client for Razorpay API.

  This library is modeled after the official Razorpay Ruby SDK (https://github.com/razorpay/razorpay-ruby)
  and provides a similar API experience for Elixir developers.

  ## Setup

      # Basic authentication (like Ruby's Razorpay.setup)
      RazorpayEx.setup("your_key_id", "your_key_secret")

      # OAuth authentication (like Ruby's Razorpay.setup_with_oauth)
      RazorpayEx.setup_with_oauth("your_access_token")

      # Set custom headers (like Ruby's Razorpay.headers=)
      RazorpayEx.headers(%{"X-Custom-Header" => "value"})

  ## Usage

      # Create an order (similar to Razorpay::Order.create)
      {:ok, order} = RazorpayEx.Order.create(%{
        amount: 50000,
        currency: "INR",
        receipt: "order_123"
      })

      # Fetch a payment (similar to Razorpay::Payment.fetch)
      {:ok, payment} = RazorpayEx.Payment.fetch("pay_123456")

  ## Supported Resources

  This SDK supports all resources from the official Ruby SDK:

    * Account
    * Customer
    * Token
    * Order
    * Payment
    * Refund
    * Invoice
    * Plan
    * Item
    * Subscription
    * AddOn
    * PaymentLink
    * Card
    * UPI
    * QRCode
    * Dispute
    * Document
    * ... and more
  """

  alias RazorpayEx.{Config, Client, Webhook}

  @doc """
  Setup basic authentication - equivalent to Ruby's `Razorpay.setup(key_id, key_secret)`
  """
  @spec setup(String.t(), String.t()) :: :ok
  def setup(key_id, key_secret) do
    Config.setup_basic_auth(key_id, key_secret)
  end

  @doc """
  Setup OAuth authentication - equivalent to Ruby's `Razorpay.setup_with_oauth(access_token)`
  """
  @spec setup_with_oauth(String.t()) :: :ok
  def setup_with_oauth(access_token) do
    Config.setup_with_oauth(access_token)
  end

  @doc """
  Set custom headers for all requests - equivalent to Ruby's `Razorpay.headers=`
  """
  @spec headers(map()) :: :ok
  def headers(custom_headers) when is_map(custom_headers) do
    Config.set_headers(custom_headers)
  end

  @doc """
  Verify webhook signature - equivalent to Ruby's webhook verification
  """
  @spec verify_webhook(String.t(), String.t(), String.t()) :: boolean()
  def verify_webhook(payload, signature, secret) do
    Webhook.verify(payload, signature, secret)
  end

  @doc """
  Returns the library version.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:razorpay_ex, :vsn)
    |> to_string()
  end

  @doc """
  Test API connectivity - useful for debugging setup.
  """
  @spec test_connection() :: {:ok, map()} | {:error, RazorpayEx.Error.t()}
  def test_connection do
    Client.request(:get, "/payments", %{}, params: %{count: 1})
  end
end
