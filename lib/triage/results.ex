# For dealing with results (:ok, :error, {:ok, ...}, and {:error, ...})
defmodule Triage.Results do
  @moduledoc false

  alias Triage.WrappedError
  require Logger

  def details({:error, %WrappedError{} = exception}) do
    errors = WrappedError.unwrap(exception)
    last_error = List.last(errors)

    metadata =
      Enum.reduce(errors, %{}, fn error, metadata ->
        Map.merge(metadata, error.metadata)
      end)

    details(last_error.result)
    |> Map.put(:metadata, metadata)
    |> Map.put(:message, Exception.message(exception))
  end

  def details({:error, %mod{} = exception} = result) when is_exception(exception) do
    %{
      type: "error",
      mod: mod,
      reason: Triage.JSON.Shrink.shrink(exception),
      message: "#{Triage.Inspect.inspect(result)} (message: #{exception_message(exception)})"
    }
  end

  def details({:error, reason} = result) do
    %{
      type: "error",
      message: Triage.Inspect.inspect(result),
      reason: Triage.JSON.Shrink.shrink(reason)
    }
  end

  def details(result)
      when is_tuple(result) and elem(result, 0) == :error do
    [:error | reasons] = Tuple.to_list(result)

    %{
      type: "error",
      message: Triage.Inspect.inspect(result),
      reasons: Triage.JSON.Shrink.shrink(reasons)
    }
  end

  def details(:error) do
    %{
      type: "error",
      message: Triage.Inspect.inspect(:error)
    }
  end

  def details({:ok, value} = result) do
    %{
      type: "ok",
      message: Triage.Inspect.inspect(result),
      value: Triage.JSON.Shrink.shrink(value)
    }
  end

  def details(result)
      when is_tuple(result) and elem(result, 0) == :ok do
    [:ok | values] = Tuple.to_list(result)

    %{
      type: "ok",
      message: Triage.Inspect.inspect(result),
      values: Triage.JSON.Shrink.shrink(values)
    }
  end

  def details(:ok) do
    %{type: "ok", message: Triage.Inspect.inspect(:ok)}
  end

  # If `result` isn't :ok/:error/{:ok, _}/{:error, _} then it was a raised exception
  def details(%mod{} = exception) when is_exception(exception) do
    %{
      type: "raise",
      message: "** (#{inspect(mod)}) #{Exception.message(exception)}",
      reason: Triage.JSON.Shrink.shrink(exception)
    }
  end

  def exception_message(%mod{} = exception) when is_exception(exception) do
    if function_exported?(mod, :message, 1) or Map.has_key?(struct(mod), :message) do
      Exception.message(exception)
    else
      Logger.warning(
        "Exception module `#{inspect(mod)}` doesn't have a `message` key or implement a `message/1` callback"
      )

      inspect(exception)
    end
  end
end
