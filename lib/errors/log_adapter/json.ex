defmodule Errors.LogAdapter.JSON do
  alias Errors.Stacktrace

  use Errors.LogAdapter

  @impl Errors.LogAdapter
  def call(log_details) do
    level = if(log_details.result_details.type == "error", do: :error, else: :info)

    stacktrace_line =
      log_details.stacktrace
      |> Stacktrace.most_relevant_entry()
      |> Stacktrace.format_file_line()

    {
      level,
      json_mod().encode!(
        data(%{
          source: "Errors",
          stacktrace_line: stacktrace_line,
          result_details: log_details.result_details
        })
      )
    }
  end

  defp data(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> data()
    |> List.to_tuple()
  end

  defp data(list) when is_list(list), do: Enum.map(list, &data/1)

  defp data(%mod{} = struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.put(:__struct__, mod)
    |> data()

    # |> Errors.Inspect.order_map_keys()
  end

  defp data(map) when is_map(map) do
    map
    |> Errors.Inspect.order_map_keys()
    |> Enum.map(&data/1)
    |> then(fn keyword_list ->
      case json_mod() do
        Jason ->
          Jason.OrderedObject.new(keyword_list)

        JSON ->
          Errors.JSONOrdered.new(keyword_list)
      end
    end)
  end

  defp data(value), do: value

  # order_map_keys

  defp json_mod do
    Application.get_env(:errors, :json, Jason)
  end
end

# Copied from https://github.com/navinpeiris/json_ordered
# Didn't want to force a dependency on users of this library for something so small
# Thank you navinpeiris!!!
#
# Namespaced to avoid a problem if somebody does bring that library in

defmodule Errors.JSONOrdered do
  defstruct [:data]

  def new(data) when is_list(data), do: %Errors.JSONOrdered{data: data}
end

defimpl JSON.Encoder, for: Errors.JSONOrdered do
  def encode(%{data: []}, _encoder), do: "{}"

  def encode(%{data: data}, encoder) do
    # Implementation inspired by the the struct encoding logic in JSON.Encoder
    # See: https://github.com/elixir-lang/elixir/blob/v1.18.1/lib/elixir/lib/json.ex#L60

    {io, _} =
      data
      |> Enum.flat_map_reduce(?{, fn {field, value}, prefix ->
        key = IO.iodata_to_binary([prefix, :elixir_json.encode_binary(Atom.to_string(field)), ?:])
        {[key, encoder.(value, encoder)], ?,}
      end)

    io ++ [?}]
  end
end
