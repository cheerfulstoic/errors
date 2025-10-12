defmodule Errors.WrappedError do
  alias Errors.Stacktrace

  @enforce_keys [:result, :reason]
  defexception [:result, :reason, :context, :stacktrace, :metadata, :message]

  # Offer `new/3` as a way to create `WrappedErrors` so that the `message` is set
  # but also create `message/1` callback in case an exception is created manually
  # See: https://hexdocs.pm/elixir/Exception.html#c:message/1

  def new(result, context, stacktrace, metadata \\ %{})
      when is_binary(context) or is_nil(context) do
    reason =
      case result do
        :error ->
          nil

        {:error, reason} ->
          reason

        other ->
          raise ArgumentError, "Errors wrap either :error or {:error, _}, got: #{inspect(other)}"
      end

    exception =
      %__MODULE__{
        result: result,
        reason: reason,
        context: context,
        stacktrace: stacktrace,
        metadata: Map.new(metadata)
      }

    %{exception | message: message(exception)}
  end

  def message(%__MODULE__{} = error) when is_binary(error.context) or is_nil(error.context) do
    {errors, root_result} = unwrap(error)

    context_string =
      errors
      |> Enum.map(fn error ->
        parts_string =
          [format_line(error), error.context, format_metadata(error)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" ")

        "    [CONTEXT] #{parts_string}"
      end)
      |> Enum.join("\n")

    reason_message =
      case Errors.reason_metadata(root_result) do
        %{mod: mod, message: message} ->
          "#{inspect(mod)}: #{message}"

        %{message: message} ->
          message
      end

    "#{reason_message}\n#{context_string}"
  end

  defp unwrap(%__MODULE__{reason: %__MODULE__{} = nested_error} = error) do
    {nested_errors, root_result} = unwrap(nested_error)

    {[error | nested_errors], root_result}
  end

  defp unwrap(%__MODULE__{} = error) do
    {[error], error.result}
  end

  defp format_line(error) do
    entry =
      error.stacktrace
      |> Stacktrace.most_relevant_entry()

    if entry do
      Stacktrace.format_file_line(entry)
    end
  end

  defp format_metadata(error) do
    if map_size(error.metadata) > 0 do
      inspect(error.metadata)
    end
  end
end

# defimpl Inspect, for: Errors.WrappedError do
#   import Inspect.Algebra
#
#   def inspect(%{reason: reason} = wrapped_error, opts) do
#     %{mod: mod, message: message} = Errors.reason_metadata(reason)
#
#     {concat([mod, ": ", message]), opts}
#   end
# end
