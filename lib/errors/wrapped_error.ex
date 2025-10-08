defmodule Errors.WrappedError do
  @enforce_keys [:reason]
  defexception [:reason, :context, :metadata, :message]

  # Offer `new/3` as a way to create `WrappedErrors` so that the `message` is set
  # but also create `message/1` callback in case an exception is created manually
  # See: https://hexdocs.pm/elixir/Exception.html#c:message/1

  def new(reason, context, metadata) when is_binary(context) do
    exception =
      %__MODULE__{
        reason: reason,
        context: context,
        metadata: metadata
      }

    %{exception | message: message(exception)}
  end

  def message(%__MODULE__{reason: reason} = error) when is_binary(error.context) do
    reason_message =
      case Errors.reason_metadata(reason) do
        %{mod: mod, message: message} ->
          "#{inspect(mod)}: #{message}"

        %{message: message} ->
          message
      end

    "WRAPPED ERROR (#{error.context}) #{reason_message}"
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
