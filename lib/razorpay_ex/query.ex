defmodule RazorpayEx.Query do
  @moduledoc """
  Encodes query parameters the way the Razorpay API expects them.

  `URI.encode_query/1` cannot express repeated keys such as
  `expand[]=card&expand[]=offer`, so this module flattens list values into
  repeated keys:

      iex> RazorpayEx.Query.encode(%{count: 10})
      "count=10"

      iex> RazorpayEx.Query.encode(%{expand: ["card", "offer"]})
      "expand%5B%5D=card&expand%5B%5D=offer"

  A list value is emitted under a `key[]` name unless the key already ends in
  `[]`, in which case it is repeated as-is. `nil` values are dropped, matching
  how the Razorpay API treats unset filters.
  """

  @doc """
  Encodes parameters into a query string (without the leading `?`).
  """
  @spec encode(map() | keyword() | nil) :: String.t()
  def encode(nil), do: ""

  def encode(params) when is_map(params) or is_list(params) do
    params
    |> Enum.flat_map(fn {key, value} -> pairs(key, value) end)
    |> Enum.map_join("&", fn {key, value} ->
      URI.encode_www_form(key) <> "=" <> URI.encode_www_form(encode_value(value))
    end)
  end

  # `expand` always travels as `expand[]`, whether the caller passed a single
  # value or a list.
  defp pairs(key, value) when key in [:expand, "expand", "expand[]"],
    do: Enum.map(List.wrap(value), &{"expand[]", &1})

  defp pairs(_key, nil), do: []

  defp pairs(key, values) when is_list(values) do
    name = key |> to_string() |> bracket()

    values
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&{name, &1})
  end

  defp pairs(key, value), do: [{to_string(key), value}]

  defp bracket(key) do
    if String.ends_with?(key, "[]"), do: key, else: key <> "[]"
  end

  defp encode_value(value) when is_binary(value), do: value
  defp encode_value(value) when is_atom(value), do: Atom.to_string(value)
  defp encode_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_value(value) when is_float(value), do: Float.to_string(value)
  defp encode_value(value), do: to_string(value)
end
