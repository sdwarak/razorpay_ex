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
          created_at: integer() | nil,
          extra: map()
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
    :created_at,
    extra: %{}
  ]

  @doc """
  Fetches a payment by ID.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, payment} = RazorpayEx.Payment.fetch("pay_29QQoUBi66xm2f")
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def fetch(id) when is_binary(id) and id != "" do
    Client.request(:get, "/payments/#{URI.encode_www_form(id)}")
  end

  def fetch(_id), do: {:error, RazorpayEx.Error.new(:bad_request, "Invalid payment ID", 400)}

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
  def capture(id, amount) when is_binary(id) and id != "" do
    Client.request(:post, "/payments/#{URI.encode_www_form(id)}/capture", %{amount: amount})
  end

  def capture(_id, _amount),
    do: {:error, RazorpayEx.Error.new(:bad_request, "Invalid payment ID", 400)}

  @doc """
  Gets card details for a payment.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, card_details} = RazorpayEx.Payment.card("pay_29QQoUBi66xm2f")
  """
  @spec card(String.t()) :: {:ok, map()} | {:error, RazorpayEx.Error.t()}
  def card(id) when is_binary(id) and id != "" do
    Client.request(:get, "/payments/#{URI.encode_www_form(id)}/card")
  end

  def card(_id), do: {:error, RazorpayEx.Error.new(:bad_request, "Invalid payment ID", 400)}

  @doc """
  Gets bank transfer details for a payment.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, bank_transfer} = RazorpayEx.Payment.bank_transfer("pay_29QQoUBi66xm2f")
  """
  @spec bank_transfer(String.t()) :: {:ok, map()} | {:error, RazorpayEx.Error.t()}
  def bank_transfer(id) when is_binary(id) and id != "" do
    Client.request(:get, "/payments/#{URI.encode_www_form(id)}/bank_transfer")
  end

  def bank_transfer(_id),
    do: {:error, RazorpayEx.Error.new(:bad_request, "Invalid payment ID", 400)}

  @doc """
  Refreshes payment status.

  ## Parameters

    - `id`: Payment ID

  ## Examples

      {:ok, payment} = RazorpayEx.Payment.refresh("pay_29QQoUBi66xm2f")
  """
  @spec refresh(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def refresh(id) when is_binary(id) and id != "" do
    Client.request(:post, "/payments/#{URI.encode_www_form(id)}/refresh", %{})
  end

  def refresh(_id), do: {:error, RazorpayEx.Error.new(:bad_request, "Invalid payment ID", 400)}

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
  def update(id, params) when is_binary(id) and id != "" do
    Client.request(:patch, "/payments/#{URI.encode_www_form(id)}", params)
  end

  def update(_id, _params),
    do: {:error, RazorpayEx.Error.new(:bad_request, "Invalid payment ID", 400)}
end
