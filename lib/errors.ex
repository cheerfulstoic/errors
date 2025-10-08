defmodule Errors do
  @moduledoc """
  Documentation for `Errors`.
  """

  require Logger

  def wrap_context(:ok, context, meta \\ %{}), do: :ok

  def wrap_context(:ok, _context, _meta), do: :ok

  def wrap_context({:ok, result}, _context, _meta) do
    {:ok, result}
  end

  def wrap_context({:error, reason}, context, metadata) do
    {:error,
     %Errors.WrappedError{
       reason: reason,
       context: context,
       metadata: metadata
     }}
  end

  def telemetry(:ok, name \\ nil), do: telemetry({:ok, nil}, name)

  def telemetry(:ok, name), do: telemetry({:ok, nil}, name)

  def telemetry({:ok, _} = result, name) do
    :telemetry.execute(
      [:errors, :success],
      %{count: 1},
      %{name: name}
    )

    result
  end

  def telemetry(:error, name), do: telemetry({:error, nil}, name)

  def telemetry({:error, reason}, name) do
    :telemetry.execute(
      [:errors, :error],
      %{count: 1},
      Map.merge(
        %{name: name},
        reason_metadata(reason)
      )
    )

    {:error}
  end

  def reason_metadata(%mod{} = exception) when is_exception(exception) do
    %{
      message: exception_message(exception),
      mod: mod
    }
  end

  def reason_metadata(reason), do: %{message: inspect(reason)}

  defp exception_message(%mod{} = exception) when is_exception(exception) do
    if function_exported?(mod, :message, 1) or Map.has_key?(struct(mod), :message) do
      Exception.message(exception)
    else
      Logger.warning(
        " ** (#{mod}) !!! Exception module doesn't have a `message` key or implement a `message/1` callback !!!"
      )

      inspect(exception)
    end
  end
end
