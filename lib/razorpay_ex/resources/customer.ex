defmodule RazorpayEx.Customer do
  @moduledoc """
  Customer resource for Razorpay API.

  This module provides functions for working with customers:
  - Create, fetch, update, and list customers
  - Manage customer details and tokens

  See: https://razorpay.com/docs/api/customers/
  """

  alias RazorpayEx.Client

  @type t :: %__MODULE__{
          id: String.t() | nil,
          entity: String.t() | nil,
          name: String.t() | nil,
          email: String.t() | nil,
          contact: String.t() | nil,
          gstin: String.t() | nil,
          notes: map() | nil,
          created_at: integer() | nil
        }

  defstruct [
    :id,
    :entity,
    :name,
    :email,
    :contact,
    :gstin,
    :notes,
    :created_at
  ]

  @doc """
  Creates a new customer.

  ## Parameters

    - `params`: Customer parameters (name, email, contact, etc.)

  ## Required Parameters

    - `name`: Customer name
    - `email`: Customer email
    - `contact`: Customer contact number

  ## Optional Parameters

    - `gstin`: Customer GSTIN
    - `notes`: Additional notes

  ## Examples

      {:ok, customer} = RazorpayEx.Customer.create(%{
        name: "John Doe",
        email: "john@example.com",
        contact: "+919999999999",
        notes: %{
          customer_since: "2023"
        }
      })
  """
  @spec create(map()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def create(params) do
    Client.request(:post, "/customers", params)
  end

  @doc """
  Fetches a customer by ID.

  ## Parameters

    - `id`: Customer ID

  ## Examples

      {:ok, customer} = RazorpayEx.Customer.fetch("cust_9A33XWu170gUtm")
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def fetch(id) do
    Client.request(:get, "/customers/#{id}")
  end

  @doc """
  Updates a customer.

  ## Parameters

    - `id`: Customer ID
    - `params`: Update parameters (name, email, contact, notes, etc.)

  ## Examples

      {:ok, customer} = Razorpay.Customer.update("cust_9A33XWu170gUtm", %{
        name: "John Updated",
        email: "updated@example.com",
        notes: %{updated_at: "2024-01-01"}
      })
  """
  @spec update(String.t(), map()) :: {:ok, t()} | {:error, RazorpayEx.Error.t()}
  def update(id, params) do
    Client.request(:put, "/customers/#{id}", params)
  end

  @doc """
  Lists all customers with optional filters.

  ## Parameters

    - `params`: Query parameters (count, skip, etc.)

  ## Examples

      # List first 10 customers
      {:ok, customers} = RazorpayEx.Customer.all(%{count: 10})
  """
  @spec all(map()) :: {:ok, list(t())} | {:error, RazorpayEx.Error.t()}
  def all(params \\ %{}) do
    Client.request(:get, "/customers", %{}, params: params)
  end
end
