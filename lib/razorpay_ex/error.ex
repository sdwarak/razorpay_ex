defmodule RazorpayEx.Error do
  @moduledoc ~S"""
  Error handling for Razorpay API.

  This module provides structured error handling for Razorpay API responses.

  Every API failure is returned as a `{:error, %RazorpayEx.Error{}}` tuple, so a
  single pattern match covers all of them; use `code` to discriminate:

      case RazorpayEx.Payment.fetch("invalid_id") do
        {:ok, payment} ->
          payment

        {:error, %RazorpayEx.Error{code: "BAD_REQUEST_ERROR"} = error} ->
          IO.puts("Bad request: #{error.description}")

        {:error, %RazorpayEx.Error{code: "NETWORK_ERROR"}} ->
          IO.puts("Could not reach Razorpay")
      end

  `RazorpayEx.Errors.BadRequestError`, `RazorpayEx.Errors.GatewayError` and
  `RazorpayEx.Errors.ServerError` are optional exception structs for callers
  that would rather raise.

  ## Error Structure

  Razorpay errors include:

    - `code`: Error code (e.g., "BAD_REQUEST_ERROR")
    - `description`: Human-readable error description
    - `field`: Field that caused the error (if applicable)
    - `step`: Step in which error occurred
    - `reason`: Reason for the error
    - `metadata`: Additional error metadata
    - `http_status_code`: HTTP status code
    - `http_body`: Raw HTTP response body
  """

  defstruct [
    :code,
    :description,
    :field,
    :step,
    :reason,
    :metadata,
    :http_status_code,
    :http_body
  ]

  @type t :: %__MODULE__{
          code: String.t(),
          description: String.t(),
          field: String.t() | nil,
          step: String.t() | nil,
          reason: String.t() | nil,
          metadata: map() | nil,
          http_status_code: integer(),
          http_body: String.t() | nil
        }

  @doc """
  Creates an error from a Razorpay error response.

  ## Parameters

    - `error_map`: Error map from Razorpay API
    - `status_code`: HTTP status code

  ## Examples

      error = Razorpay.Error.from_map(%{
        "code" => "BAD_REQUEST_ERROR",
        "description" => "Invalid payment id"
      }, 400)
  """
  @spec from_map(map(), integer()) :: t()
  def from_map(error_map, status_code) when is_map(error_map) do
    %__MODULE__{
      code: Map.get(error_map, "code", "UNKNOWN_ERROR"),
      description: Map.get(error_map, "description"),
      field: Map.get(error_map, "field"),
      step: Map.get(error_map, "step"),
      reason: Map.get(error_map, "reason"),
      metadata: Map.get(error_map, "metadata"),
      http_status_code: status_code,
      http_body: Jason.encode!(error_map)
    }
  end

  @doc """
  Creates a new error.

  ## Parameters

    - `type`: Error type atom or string
    - `description`: Error description
    - `status_code`: HTTP status code (default: 0)

  ## Examples

      error = RazorpayEx.Error.new(:network_error, "Connection failed")
      error = RazorpayEx.Error.new("BAD_REQUEST", "Invalid input", 400)
  """
  @spec new(atom() | String.t(), String.t(), integer()) :: t()
  def new(type, description, status_code \\ 0)

  def new(:network_error, description, status_code) do
    %__MODULE__{
      code: "NETWORK_ERROR",
      description: description,
      http_status_code: status_code
    }
  end

  def new(:invalid_json, description, status_code) do
    %__MODULE__{
      code: "INVALID_JSON",
      description: description,
      http_status_code: status_code
    }
  end

  def new(:timeout, description, status_code) do
    %__MODULE__{
      code: "TIMEOUT_ERROR",
      description: description,
      http_status_code: status_code
    }
  end

  def new(code, description, status_code) when is_atom(code) do
    %__MODULE__{
      code: code |> Atom.to_string() |> String.upcase(),
      description: description,
      http_status_code: status_code
    }
  end

  def new(code, description, status_code) when is_binary(code) do
    %__MODULE__{
      code: code,
      description: description,
      http_status_code: status_code
    }
  end

  @doc """
  Returns a string representation of the error.
  """
  @spec message(t()) :: String.t()
  def message(error) do
    parts = [
      "Razorpay Error: #{error.code}",
      "Description: #{error.description}",
      if(error.field, do: "Field: #{error.field}", else: nil),
      if(error.http_status_code > 0, do: "HTTP Status: #{error.http_status_code}", else: nil)
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end
end
