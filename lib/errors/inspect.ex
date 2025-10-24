defmodule Errors.Inspect do
  @moduledoc """
  Logic to do smart inspecting of values.  Part of that is outputting only the most useful
  attributes for debugging (IDs, names, etc...)
  """

  defmodule Wrapper do
    @moduledoc """
    Struct to simply hold some term(). To be able to render an inspect string
    by controlling the algebra (see `defimpl Inspect, for: Errors.Inspect.Wrapper do` below)
    If there's an official way in the Elixir API to take algebra and turn it into a string
    then that would be better
    """

    defstruct [:value]
  end

  def inspect(value, opts \\ []) do
    Kernel.inspect(wrap_value(value), opts)
  end

  defp wrap_value(list) when is_list(list) do
    Enum.map(list, &wrap_value/1)
  end

  defp wrap_value(%mod{} = struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> wrap_value()
    |> then(&struct(mod, &1))
    |> then(&%Wrapper{value: &1})
  end

  defp wrap_value(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {key, wrap_value(value)}
    end)
  end

  defp wrap_value(value), do: value
end

defimpl Inspect, for: Errors.Inspect.Wrapper do
  def inspect(%{value: value}, opts) do
    inspect_value(value, opts)
  end

  defp inspect_value(%mod{} = struct, opts) do
    map = Map.from_struct(struct)

    fields =
      mod.__info__(:struct)
      |> Enum.filter(&include_key_value?(mod, &1.field, map[&1.field]))
      |> order_fields()

    try do
      # The `inspect/4` function was changed to `inspect_as_struct/4` in Elixir 1.19
      Inspect.Any.inspect_as_struct(map, Macro.inspect_atom(:literal, mod), fields, opts)
    rescue
      UndefinedFunctionError ->
        Inspect.Any.inspect(map, Macro.inspect_atom(:literal, mod), fields, opts)
    end
  end

  defp inspect_value(value, opts), do: Inspect.inspect(value, opts)

  defp order_fields(fields) do
    field_index_func = fn
      :id -> -3
      "id" -> -3
      :name -> -2
      "name" -> -2
      :__struct__ -> -1
      "__struct__" -> -1
      key -> to_string(key)
    end

    Enum.sort_by(fields, fn %{field: field} -> field_index_func.(field) end)
  end

  defp include_key_value?(Ecto.Changeset, key, _) do
    key in ~w[action changes data errors params valid?]a
  end

  defp include_key_value?(_, key, _) when key in [:id, "id", :name, "name", :status, "status"] do
    true
  end

  defp include_key_value?(_, key, value) do
    Regex.match?(~r/[a-z](_id|Id|ID)$/, to_string(key)) or
      (is_map(value) and map_size(value) > 0) or
      is_list(value) or is_struct(value)
  end
end
