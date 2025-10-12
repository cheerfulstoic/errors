defmodule Errors.WrappedError do
  alias Errors.Stacktrace

  @enforce_keys [:result, :reason]
  defexception [:result, :reason, :context, :stacktrace, :metadata, :message]

  # Offer `new/3` as a way to create `WrappedErrors` so that the `message` is set
  # but also create `message/1` callback in case an exception is created manually
  # See: https://hexdocs.pm/elixir/Exception.html#c:message/1

  def new(result, context, stacktrace, metadata \\ %{}) when is_binary(context) do
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

  def message(%__MODULE__{} = error) when is_binary(error.context) do
    {details, root_result} = unwrap(error)

    context_string =
      details
      |> Enum.map(&"    [CONTEXT] #{&1.formatted_line}#{&1.context}")
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

  defp unwrap(%__MODULE__{
         reason: %__MODULE__{} = nested_error,
         context: context,
         stacktrace: stacktrace
       }) do
    {nested_context, root_result} = unwrap(nested_error)

    {[%{context: context, formatted_line: formatted_line(stacktrace)} | nested_context],
     root_result}
  end

  defp unwrap(%__MODULE__{result: result, context: context, stacktrace: stacktrace}) do
    {[%{context: context, formatted_line: formatted_line(stacktrace)}], result}
  end

  defp formatted_line(stacktrace) do
    stacktrace
    |> Stacktrace.most_relevant_entry()
    |> case do
      nil ->
        nil

      entry ->
        Stacktrace.format_file_line(entry)
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
