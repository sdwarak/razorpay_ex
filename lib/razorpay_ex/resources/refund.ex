defmodule RazorpayEx.Refund do
  @moduledoc """
  Refund resource for Razorpay API.

  This module provides functions for working with refunds:
  - Create, fetch, and list refunds
  - Process refunds for payments

  See: https://razorpay.com/docs/api/refunds/
  """

  alias RazorpayEx.Client

  @type t :: %__MODULE__{
          id: String.t() | nil,
          entity: String.t() | nil,
          amount: integer() | nil,
          currency: String.t() | nil,
          payment_id: String.t() | nil,
          notes: map() | nil,
          receipt: String.t() | nil,
          acquirer_data: map() | nil,
          created_at: integer() | nil,
          batch_id: String.t() | nil,
          status: String.t() | nil,
          speed_processed: String.t() | nil,
          speed_requested: String.t() | nil
        }

  defstruct [
    :id,
    :entity,
    :amount,
    :currency,
    :payment_id,
    :notes,
    :receipt,
    :acquirer_data,
    :created_at,
    :batch_id,
    :status,
    :speed_processed,
    :speed_requested
  ]

  @doc """
  Creates a refund for a payment.

  ## Parameters

    - `payment_id`: Payment ID
    - `params`: Refund parameters (amount, notes, etc.)

  ## Required Parameters

    - `amount`: Amount to refund (in paise)

  ## Optional Parameters

    - `notes`: Additional notes
    - `receipt`: Your refund receipt ID
    - `speed`: Refund speed ("normal", "optimum")

  ## Examples

      # Full refund
      {:ok, refund} = RazorpayEx.Refund.create("pay_29QQoUBi66xm2f", %{
        amount: 50000
      })

      # Partial refund with notes
      {:ok, refund} = RazorpayEx.Refund.create("pay_29QQoUBi66xm2f", %{
        amount: 25000,
        notes: %{reason: "Defective product"},
        speed: "optimum"
      })
  """
  @spec create(String.t(), map()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def create(payment_id, params) do
    Client.request(:post, "/payments/#{payment_id}/refund", params)
  end

  @doc """
  Fetches a refund by ID.

  ## Parameters

    - `id`: Refund ID

  ## Examples

      {:ok, refund} = RazorpayEx.Refund.fetch("rfnd_9A33XWu170gUtm")
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def fetch(id) do
    Client.request(:get, "/refunds/#{id}")
  end

  @doc """
  Lists all refunds with optional filters.

  ## Parameters

    - `params`: Query parameters (count, skip, payment_id, etc.)

  ## Examples

      # List first 10 refunds
      {:ok, refunds} = RazorpayEx.Refund.all(%{count: 10})

      # List refunds for a specific payment
      {:ok, refunds} = RazorpayEx.Refund.all(%{payment_id: "pay_29QQoUBi66xm2f"})
  """
  @spec all(map()) :: {:ok, list(t())} | {:error, RazorpayEx.Error.t()}
  def all(params \\ %{}) do
    Client.request(:get, "/refunds", %{}, params: params)
  end

  @doc """
  Fetches multiple refunds for a payment.

  ## Parameters

    - `payment_id`: Payment ID
    - `params`: Query parameters

  ## Examples

      {:ok, refunds} = RazorpayEx.Refund.for_payment("pay_29QQoUBi66xm2f")
  """
  @spec for_payment(String.t(), map()) :: {:ok, list(t())} | {:error, RazorpayEx.Error.t()}
  def for_payment(payment_id, params \\ %{}) do
    Client.request(:get, "/payments/#{payment_id}/refunds", %{}, params: params)
  end
end
