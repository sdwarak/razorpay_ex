defmodule RazorpayEx.Order do
  @moduledoc """
  Order resource for Razorpay API.

  This module provides functions for working with orders:
  - Create, fetch, and list orders
  - Update orders
  - Get payments for orders

  See: https://razorpay.com/docs/api/orders/
  """

  alias RazorpayEx.Client

  @type t :: %__MODULE__{
          id: String.t() | nil,
          entity: String.t() | nil,
          amount: integer() | nil,
          amount_paid: integer() | nil,
          amount_due: integer() | nil,
          currency: String.t() | nil,
          receipt: String.t() | nil,
          status: String.t() | nil,
          attempts: integer() | nil,
          notes: map() | nil,
          created_at: integer() | nil,
          offer_id: String.t() | nil
        }

  defstruct [
    :id,
    :entity,
    :amount,
    :amount_paid,
    :amount_due,
    :currency,
    :receipt,
    :status,
    :attempts,
    :notes,
    :created_at,
    :offer_id
  ]

  @doc """
  Creates a new order.

  ## Parameters

    - `params`: Order parameters (amount, currency, receipt, etc.)

  ## Required Parameters

    - `amount`: Amount in paise (₹1 = 100 paise)
    - `currency`: Currency code (e.g., "INR")

  ## Optional Parameters

    - `receipt`: Your order receipt ID
    - `payment_capture`: Auto-capture payment (true/false)
    - `notes`: Additional notes
    - `method`: Allowed payment methods

  ## Examples

      {:ok, order} = RazorpayEx.Order.create(%{
        amount: 50000,
        currency: "INR",
        receipt: "order_rcptid_11",
        payment_capture: true,
        notes: %{
          customer_name: "John Doe"
        }
      })
  """
  @spec create(map()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def create(params) do
    Client.request(:post, "/orders", params)
  end

  @doc """
  Fetches an order by ID.

  ## Parameters

    - `id`: Order ID

  ## Examples

      {:ok, order} = RazorpayEx.Order.fetch("order_9A33XWu170gUtm")
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def fetch(id) do
    Client.request(:get, "/orders/#{id}")
  end

  @doc """
  Lists all orders with optional filters.

  ## Parameters

    - `params`: Query parameters (count, skip, from, to, etc.)

  ## Examples

      # List first 10 orders
      {:ok, orders} = RazorpayEx.Order.all(%{count: 10})

      # List authorized orders
      {:ok, orders} = RazorpayEx.Order.all(%{status: "authorized"})
  """
  @spec all(map()) :: {:ok, list(t())} | {:error, RazorpayEx.Error.t()}
  def all(params \\ %{}) do
    Client.request(:get, "/orders", %{}, params: params)
  end

  @doc """
  Updates an order.

  ## Parameters

    - `id`: Order ID
    - `params`: Update parameters (notes, etc.)

  ## Examples

      {:ok, order} = RazorpayEx.Order.update("order_9A33XWu170gUtm", %{
        notes: %{updated_reason: "Customer requested update"}
      })
  """
  @spec update(String.t(), map()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def update(id, params) do
    Client.request(:patch, "/orders/#{id}", params)
  end

  @doc """
  Gets payments for an order.

  ## Parameters

    - `id`: Order ID
    - `params`: Query parameters

  ## Examples

      {:ok, payments} = RazorpayEx.Order.payments("order_9A33XWu170gUtm")
  """
  @spec payments(String.t(), map()) :: {:ok, list(RazorpayEx.Payment.t())} | {:error, Razorpay.Error.t()}
  def payments(id, params \\ %{}) do
    Client.request(:get, "/orders/#{id}/payments", %{}, params: params)
  end
end
