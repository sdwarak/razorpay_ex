defmodule RazorpayEx.Entity do
  @moduledoc """
  Base entity module for all Razorpay resources.

  This module provides the foundation for all Razorpay resource structs,
  similar to how Ruby SDK uses inheritance for entities.
  """

  alias RazorpayEx.{Constants, Client}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          entity: String.t() | nil,
          created_at: integer() | nil
        }

  defstruct [
    :id,
    :entity,
    :created_at
  ]

  @doc """
  Creates an entity struct from a map.

  ## Examples

      RazorpayEx.Entity.from_map(%{"id" => "pay_123", "entity" => "payment"})
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    struct(__MODULE__, map)
  end

  @doc """
  Converts an entity to a map, filtering out nil values.
  """
  @spec to_map(t()) :: map()
  def to_map(entity) do
    Map.from_struct(entity)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Dynamically creates a struct for a given entity type.

  This mimics Ruby SDK's dynamic class creation based on entity names.

  ## Examples

      RazorpayEx.Entity.build("payment", %{"id" => "pay_123", "amount" => 5000})
  """
  @spec build(String.t(), map()) :: struct()
  def build(entity_name, attributes) when is_binary(entity_name) do
    # Convert entity name to module name (e.g., "payment" -> RazorpayEx.Payment)
    module_name =
      entity_name
      |> String.split("_")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join("")

    try do
      module = Module.safe_concat([RazorpayEx, module_name])
      struct(module, attributes)
    rescue
      ArgumentError ->
        # Fall back to base entity if specific module doesn't exist
        struct(__MODULE__, Map.put(attributes, "entity", entity_name))
    end
  end

  @doc """
  Fetches an entity by ID for a given resource type.

  Similar to Ruby SDK's instance.fetch method.
  """
  @spec fetch(String.t(), atom()) :: {:ok, struct()} | {:error, RazorpayEx.Error.t()}
  def fetch(id, resource_type) do
    endpoint = Constants.endpoint_path(resource_type)
    Client.request(:get, "/#{Constants.api_version()}/#{endpoint}/#{id}")
  end

  @doc """
  Lists entities for a given resource type.

  Similar to Ruby SDK's class.all method.
  """
  @spec all(atom(), map()) :: {:ok, list(struct())} | {:error, RazorpayEx.Error.t()}
  def all(resource_type, params \\ %{}) do
    endpoint = Constants.endpoint_path(resource_type)
    Client.request(:get, "/#{Constants.api_version()}/#{endpoint}", %{}, params: params)
  end
end
