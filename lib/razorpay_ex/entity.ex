defmodule RazorpayEx.Entity do
  @moduledoc """
  Base entity module for all Razorpay resources.

  API payloads are cast into the struct matching their `"entity"` field when one
  exists (for example `"payment"` becomes `RazorpayEx.Payment`). Fields that the
  struct does not model are preserved verbatim in the `:extra` field, so casting
  a response never drops data.

      {:ok, payment} = RazorpayEx.Payment.fetch("pay_29QQoUBi66xm2f")
      payment.amount            #=> 50000
      payment.extra["acquirer_data"]  #=> %{"rrn" => "..."}

  Entity types without a dedicated module are cast into `RazorpayEx.Entity`,
  which keeps every field in `:extra`.
  """

  alias RazorpayEx.{Client, Constants}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          entity: String.t() | nil,
          created_at: integer() | nil,
          extra: map()
        }

  defstruct [:id, :entity, :created_at, extra: %{}]

  @doc """
  Creates an entity struct from a map.

  ## Examples

      RazorpayEx.Entity.from_map(%{"id" => "pay_123", "entity" => "payment"})
  """
  @spec from_map(map()) :: struct()
  def from_map(map) when is_map(map), do: build(map)

  @doc """
  Converts an entity to a map, filtering out nil values and an empty `:extra`.
  """
  @spec to_map(struct()) :: map()
  def to_map(entity) do
    entity
    |> Map.from_struct()
    |> Enum.reject(fn {key, value} -> is_nil(value) or (key == :extra and value == %{}) end)
    |> Map.new()
  end

  @doc """
  Builds an entity from an API payload, using its `"entity"` field to pick the
  struct module.

  ## Examples

      RazorpayEx.Entity.build(%{"entity" => "payment", "id" => "pay_123"})
  """
  @spec build(map()) :: struct()
  def build(%{} = data), do: build(entity_name(data), data)

  @doc """
  Builds an entity struct for the given entity name.

  Both string and atom keys are accepted. Unknown fields are kept in `:extra`.

  ## Examples

      RazorpayEx.Entity.build("payment", %{"id" => "pay_123", "amount" => 5000})
  """
  @spec build(String.t() | atom() | nil, map()) :: struct()
  def build(nil, %{} = attributes), do: cast(__MODULE__, attributes)

  def build(entity_name, %{} = attributes) when is_atom(entity_name),
    do: cast(module_for(to_string(entity_name)), attributes)

  def build(entity_name, %{} = attributes) when is_binary(entity_name),
    do: cast(module_for(entity_name), attributes)

  @doc """
  Casts a map into the given struct module.

  Keys that exist in the struct are assigned to their fields; every other key is
  stored in the `:extra` field. Atom conversion only ever targets atoms that
  already exist, so untrusted API payloads cannot exhaust the atom table.
  """
  @spec cast(module(), map()) :: struct()
  def cast(module, %{} = data) when is_atom(module) do
    structure = struct(module)
    fields = Map.keys(structure)
    {known, extra} = Enum.reduce(data, {%{}, %{}}, &split_field(&1, &2, fields))

    structure
    |> Map.merge(known)
    |> Map.put(:extra, extra)
  end

  defp split_field({key, value}, {known, extra}, fields) do
    case existing_atom(key) do
      nil ->
        {known, Map.put(extra, key, value)}

      atom ->
        if atom in fields do
          {Map.put(known, atom, value), extra}
        else
          {known, Map.put(extra, key, value)}
        end
    end
  end

  @doc """
  Resolves the struct module for an entity name, falling back to
  `RazorpayEx.Entity` when the library does not implement that resource.

  Module names are looked up as existing atoms only.
  """
  @spec module_for(String.t()) :: module()
  def module_for(entity_name) when is_binary(entity_name) do
    name = "Elixir.RazorpayEx." <> Macro.camelize(entity_name)

    with {:ok, module} <- existing_module(name),
         true <- struct_module?(module) do
      module
    else
      _ -> __MODULE__
    end
  end

  @doc """
  Fetches an entity by ID for a given resource type.

  ## Examples

      RazorpayEx.Entity.fetch("pay_29QQoUBi66xm2f", :payment)
  """
  @spec fetch(String.t(), atom()) :: Client.response()
  def fetch(id, resource_type) do
    Client.request(:get, "/#{Constants.endpoint_path(resource_type)}/#{id}")
  end

  @doc """
  Lists entities for a given resource type.

  ## Examples

      RazorpayEx.Entity.all(:payment, %{count: 10})
  """
  @spec all(atom(), map()) :: Client.response()
  def all(resource_type, params \\ %{}) do
    Client.request(:get, "/#{Constants.endpoint_path(resource_type)}", %{}, params: params)
  end

  defp entity_name(%{} = data) do
    Map.get(data, "entity") || Map.get(data, :entity)
  end

  defp existing_module(name) do
    {:ok, String.to_existing_atom(name)}
  rescue
    ArgumentError -> :error
  end

  defp struct_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0)
  end

  defp existing_atom(key) when is_atom(key), do: key

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp existing_atom(_key), do: nil
end
