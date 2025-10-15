defmodule Errors.Inspect do
  @max_shrunken_entities 10

  def inspect(value) do
    case Inspect.impl_for(value) do
      Inspect.Any ->
        shrunken_inspect(value)

      _ ->
        Kernel.inspect(value)
    end
  end

  defp shrunken_inspect(value) do
    value
    |> shrunken_representation()
    |> Map.delete(:__message__)
    |> inspect_shrunken_representation()
  end

  defp inspect_shrunken_representation(%{__struct__: mod} = shrunken_representation) do
    shrunken_representation =
      shrunken_representation
      |> Map.delete(:__struct__)

    if map_size(shrunken_representation) > 0 do
      "##{mod}<#{attributes_string(shrunken_representation)}, ...>"
    else
      "##{mod}<...>"
    end
  end

  defp inspect_shrunken_representation(%{} = shrunken_representation) do
    "#<#{attributes_string(shrunken_representation)}, ...>"
  end

  defp inspect_shrunken_representation(shrunken_representation)
       when is_list(shrunken_representation) do
    "[" <>
      Enum.map_join(shrunken_representation, ", ", &inspect_shrunken_representation/1) <> ", ...]"
  end

  defp inspect_shrunken_representation(shrunken_representation) do
    Kernel.inspect(shrunken_representation)
  end

  defp attributes_string(attributes) do
    attributes
    |> Enum.sort_by(fn
      {:id, _} -> -1
      {"id", _} -> -1
      {key, _} -> to_string(key)
    end)
    |> Enum.map_join(", ", fn {key, value} ->
      "#{key}: #{inspect_shrunken_representation(value)}"
    end)
  end

  # This function exists to reduce the data that is sent out (logs/teleetry) to
  # the fields that are the most useful for debugging.  Currently that is
  # just identifying fields (`id` or `*_id` fields, along with `type` fields
  # to identify structs), but it could be other things later if we can
  # algorithmically identify fields which would be generically helpful when
  # debugging
  def shrunken_representation(data, sub_value? \\ false)

  def shrunken_representation(
        %Errors.WrappedError{
          # result: result,
        } = exception,
        _sub_value?
      ) do
    errors = Errors.WrappedError.unwrap(exception)
    last_error = List.last(errors)

    contexts =
      Enum.map(errors, fn error ->
        %{
          label: error.context,
          stacktrace: format_stacktrace(error.stacktrace),
          metadata: shrunken_representation(error.metadata)
        }
      end)

    %{
      __root_reason__: shrunken_representation(last_error.reason),
      __contexts__: contexts
    }
  end

  def shrunken_representation(exception, _sub_value?) when is_exception(exception) do
    exception
    |> Map.from_struct()
    |> Map.delete(:__exception__)
    |> Map.delete(:message)
    |> Map.put(:__struct__, Macro.to_string(exception.__struct__))
    |> Map.put(:__message__, Exception.message(exception))

    # TODO: shrink / reduce values?
  end

  def shrunken_representation(%mod{} = struct, _sub_value?) do
    map =
      struct
      |> Map.from_struct()
      |> shrunken_representation(true)

    if map_size(map) > 0 do
      map
      |> Map.put(:__struct__, Macro.to_string(mod))
      |> customize_fields(mod, struct)
    else
      map
    end
  end

  def shrunken_representation(map, sub_value?) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_map(value) or is_list(value) ->
        {key, shrunken_representation(value, true)}

      {key, value} ->
        {key, value}
    end)
    |> Enum.filter(fn
      {_, :__LIST_WITHOUT_ITEMS__} ->
        false

      {_, nil} ->
        !sub_value?

      {key, _} when key in [:id, "id", :name, "name"] ->
        true

      {key, value} ->
        Regex.match?(~r/[a-z](_id|Id|ID)$/, to_string(key)) or
          (is_map(value) and map_size(value) > 0) or
          is_list(value)
    end)
    |> Enum.into(%{})
  end

  def shrunken_representation(list, sub_value?) when is_list(list) do
    if length(list) > 0 and Keyword.keyword?(list) do
      list
      |> Enum.into(%{})
      |> shrunken_representation(true)
    else
      result = Enum.map(list, &shrunken_representation(&1, true))

      cond do
        Enum.empty?(result) ->
          []

        Enum.any?(result, &stripped_value_is_valuable?(&1, sub_value?)) ->
          truncate_list_to(result, @max_shrunken_entities)

        true ->
          :__LIST_WITHOUT_ITEMS__
      end
    end
  end

  def shrunken_representation(value, _sub_value?), do: value

  defp truncate_list_to(list, size)
       when is_list(list) and is_integer(size) and length(list) <= size,
       do: list

  defp truncate_list_to(list, size) when is_list(list) and is_integer(size) do
    Enum.take(list, size) ++ ["... #{length(list) - size} additional item(s) truncated ..."]
  end

  defp customize_fields(map, MyApp.Accounts.User, original) do
    map
    |> Map.put(:name, original.name)
    |> Map.put(:is_admin, original.is_admin)
  end

  defp customize_fields(map, _, _), do: map

  # Turns stacktrace into an array of strings for readability in logs
  def format_stacktrace(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp stripped_value_is_valuable?(map, _) when is_map(map), do: map_size(map) > 0
  defp stripped_value_is_valuable?(list, _) when is_list(list), do: length(list) > 0
  defp stripped_value_is_valuable?(_, true), do: false
  defp stripped_value_is_valuable?(_, _), do: true
end
