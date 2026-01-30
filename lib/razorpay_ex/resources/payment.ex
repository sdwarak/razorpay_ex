defmodule RazorpayEx.Payment do
  @moduledoc """
  Payment resource for Razorpay API.

  This module provides functions for working with payments:
  - Create, fetch, and list payments
  - Capture payments
  - Refund payments
  - Get payment details

  See: https://razorpay.com/docs/api/payments/
  """

  alias RazorpayEx.Client

  @type t :: %__MODULE__{
          id: String.t() | nil,
          entity: String.t() | nil,
          amount: integer() | nil,
          currency: String.t() | nil,
          status: String.t() | nil,
          order_id: String.t() | nil,
          invoice_id: String.t() | nil,
          international: boolean() | nil,
          method: String.t() | nil,
          amount_refunded: integer() | nil,
          refund_status: String.t() | nil,
          captured: boolean() | nil,
          description: String.t() | nil,
          card_id: String.t() | nil,
          bank: String.t() | nil,
          wallet: String.t() | nil,
          vpa: String.t() | nil,
          email: String.t() | nil,
          contact: String.t() | nil,
          notes: map() | nil,
          fee: integer() | nil,
          tax: integer() | nil,
          error_code: String.t() | nil,
          error_description: String.t() | nil,
          created_at: integer() | nil
        }

  defstruct [
    :id,
    :entity,
    :amount,
    :currency,
    :status,
    :order_id,
    :invoice_id,
    :international,
    :method,
    :amount_refunded,
    :refund_status,
    :captured,
    :description,
    :card_id,
    :bank,
    :wallet,
    :vpa,
    :email,
    :contact,
    :notes,
    :fee,
    :tax,
    :error_code,
    :error_description,
    :created_at
  ]

  @doc """
  Fetches a payment by ID.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, payment} = RazorpayEx.Payment.fetch("pay_29QQoUBi66xm2f")
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def fetch(id) do
    Client.request(:get, "/payments/#{id}")
  end

  @doc """
  Lists all payments with optional filters.

  ## Parameters

    - `params`: Query parameters (count, skip, from, to, etc.)

  ## Examples

      # List first 10 payments
      {:ok, payments} = Razorpay.Payment.all(%{count: 10})

      # List payments from a specific date
      {:ok, payments} = RazorpayEx.Payment.all(%{from: 1633046400, to: 1633132800})
  """
  @spec all(map()) :: {:ok, list(t())} | {:error, RazorpayEx.Error.t()}
  def all(params \\ %{}) do
    Client.request(:get, "/payments", %{}, params: params)
  end

  @doc """
  Captures a payment.

  ## Parameters

    - `id`: Payment ID
    - `amount`: Amount to capture (in paise)

  ## Examples

      # Capture full amount
      {:ok, payment} = RazorpayEx.Payment.capture("pay_29QQoUBi66xm2f", 50000)

      # Capture partial amount
      {:ok, payment} = RazorpayEx.Payment.capture("pay_29QQoUBi66xm2f", 25000)
  """
  @spec capture(String.t(), integer()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def capture(id, amount) do
    Client.request(:post, "/payments/#{id}/capture", %{amount: amount})
  end

  @doc """
  Gets card details for a payment.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, card_details} = RazorpayEx.Payment.card("pay_29QQoUBi66xm2f")
  """
  @spec card(String.t()) :: {:ok, map()} | {:error, RazorpayEx.Error.t()}
  def card(id) do
    Client.request(:get, "/payments/#{id}/card")
  end

  @doc """
  Gets bank transfer details for a payment.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, bank_transfer} = RazorpayEx.Payment.bank_transfer("pay_29QQoUBi66xm2f")
  """
  @spec bank_transfer(String.t()) :: {:ok, map()} | {:error, RazorpayEx.Error.t()}
  def bank_transfer(id) do
    Client.request(:get, "/payments/#{id}/bank_transfer")
  end

  @doc """
  Refreshes payment status.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, payment} = RazorpayEx.Payment.refresh("pay_29QQoUBi66xm2f")
  """
  @spec refresh(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def refresh(id) do
    Client.request(:post, "/payments/#{id}/refresh", %{})
  end

  @doc """
  Updates payment details.

  ## Parameters

    - `id`: Payment ID
    - `params`: Update parameters (notes, etc.)

  ## Examples

      {:ok, payment} = Razorpay.Payment.update("pay_29QQoUBi66xm2f", %{
        notes: %{updated_reason: "Customer requested update"}
      })
  """
  @spec update(String.t(), map()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def update(id, params) do
    Client.request(:patch, "/payments/#{id}", params)
  end
end
