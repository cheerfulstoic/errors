defmodule Errors.JSON do
  # This function exists to reduce the data that is sent out (logs/teleetry) to
  # the fields that are the most useful for debugging.  Currently that is
  # just identifying fields (`id` or `*_id` fields, along with `type` fields
  # to identify structs), but it could be other things later if we can
  # algorithmically identify fields which would be generically helpful when
  # debugging

  defprotocol Shrink do
    @fallback_to_any true

    @spec shrink(t) :: term()
    def shrink(value)
  end
end

defimpl Errors.JSON.Shrink, for: Errors.WrappedError do
  def shrink(exception) do
    errors = Errors.WrappedError.unwrap(exception)
    last_error = List.last(errors)

    contexts =
      Enum.map(errors, fn error ->
        %{
          label: Errors.JSON.Shrink.shrink(error.context),
          stacktrace: format_stacktrace(error.stacktrace),
          metadata: Errors.JSON.Shrink.shrink(error.metadata)
        }
      end)

    %{
      __root_reason__: Errors.JSON.Shrink.shrink(last_error.reason),
      __contexts__: contexts
    }
  end

  # Turns stacktrace into an array of strings for readability in logs
  def format_stacktrace(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
  end
end

# Fallback to Any so that apps can implement overrides
defimpl Errors.JSON.Shrink, for: Any do
  def shrink(exception) when is_exception(exception) do
    exception
    |> Map.from_struct()
    |> Map.delete(:__exception__)
    |> Map.delete(:message)
    |> Map.put(:__struct__, Macro.to_string(exception.__struct__))
    |> Map.put(:__message__, Exception.message(exception))
  end

  def shrink(%mod{} = struct) do
    map =
      struct
      |> Map.from_struct()
      |> Errors.JSON.Shrink.shrink()

    if map_size(map) > 0 do
      map
      |> Map.put(:__struct__, Macro.to_string(mod))
      |> customize_fields(mod, struct)
    else
      map
    end
  end

  def shrink(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value}
      when is_map(value) or is_list(value) or is_tuple(value) or is_function(value) ->
        {key, Errors.JSON.Shrink.shrink(value)}

      {key, value} ->
        {key, value}
    end)
    |> Enum.filter(fn
      {_, :__LIST_WITHOUT_ITEMS__} ->
        false

      # {_, nil} ->
      #   !sub_value?

      {key, _} when key in [:id, "id", :name, "name"] ->
        true

      {key, value} ->
        Regex.match?(~r/[a-z](_id|Id|ID)$/, to_string(key)) or
          (is_map(value) and map_size(value) > 0) or
          is_list(value)
    end)
    |> Enum.into(%{})
  end

  def shrink(list) when is_list(list) do
    if length(list) > 0 and Keyword.keyword?(list) do
      list
      |> Enum.into(%{})
      |> Errors.JSON.Shrink.shrink()
    else
      Enum.map(list, &Errors.JSON.Shrink.shrink(&1))
    end
  end

  # Not 100% sure about this approach, but trying it for now 🤷‍♂️
  def shrink(tuple) when is_tuple(tuple), do: Kernel.inspect(tuple)

  def shrink(func) when is_function(func) do
    function_info = Function.info(func)

    "&#{Kernel.inspect(function_info[:module])}.#{function_info[:name]}/#{function_info[:arity]}"
  end

  def shrink(string) when is_binary(string) do
    case Jason.encode(string) do
      {:ok, _} -> string
      {:error, _} -> inspect(string)
    end
  end

  def shrink(value), do: value

  defp customize_fields(map, MyApp.Accounts.User, original) do
    map
    |> Map.put(:name, original.name)
    |> Map.put(:is_admin, original.is_admin)
  end

  defp customize_fields(map, _, _), do: map
end
