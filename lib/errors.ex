defmodule Errors do
  @moduledoc """
  Documentation for `Errors`.
  """

  alias Errors.Stacktrace
  alias Errors.LogAdapter
  alias Errors.WrappedError
  require Logger
  require Stacktrace

  def wrap_context(:ok, _meta), do: :ok

  def wrap_context({:ok, result}, _meta) do
    {:ok, result}
  end

  def wrap_context(:error, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, WrappedError.new(:error, nil, stacktrace, metadata)}
  end

  def wrap_context({:error, reason}, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, WrappedError.new({:error, reason}, nil, stacktrace, metadata)}
  end

  def wrap_context(result, context, meta \\ %{})

  def wrap_context(:ok, _context, _meta), do: :ok

  def wrap_context({:ok, result}, _context, _meta) do
    {:ok, result}
  end

  def wrap_context(:error, context, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, WrappedError.new(:error, context, stacktrace, metadata)}
  end

  def wrap_context({:error, reason}, context, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, WrappedError.new({:error, reason}, context, stacktrace, metadata)}
  end

  def step!(func) do
    case func.() do
      :ok -> :ok
      {:ok, _} = result -> result
      :error -> :error
      {:error, _} = result -> result
      other -> {:ok, other}
    end
  end

  # def telemetry(:ok, name \\ nil), do: telemetry({:ok, nil}, name)
  #
  # def telemetry(:ok, name), do: telemetry({:ok, nil}, name)
  #
  # def telemetry({:ok, _} = result, name) do
  #   :telemetry.execute(
  #     [:errors, :ok],
  #     %{count: 1},
  #     %{name: name}
  #   )
  #
  #   result
  # end
  #
  # def telemetry(:error, name), do: telemetry({:error, nil}, name)
  #
  # def telemetry({:error, reason}, name) do
  #   :telemetry.execute(
  #     [:errors, :error],
  #     %{count: 1},
  #     Map.merge(
  #       %{name: name},
  #       result_details(reason)
  #     )
  #   )
  #
  #   {:error}
  # end

  # Telemetry metadata:
  #   result_type: :ok / :error
  #   result_value:
  #    * 123
  #    * %MyApp.Accounts.User{id: 123, ...}
  #    * #Ecto.Changeset<action: ..., changes: ..., ...>

  def result_details({:error, %WrappedError{} = exception}) do
    %{
      type: "error",
      message: Exception.message(exception),
      value: Errors.Inspect.shrunken_representation(exception)
    }
  end

  def result_details({:error, %mod{} = exception}) when is_exception(exception) do
    %{
      type: "error",
      mod: mod,
      message:
        "{:error, #{Errors.Inspect.inspect(exception)}} (message: #{exception_message(exception)})",
      value: Errors.Inspect.shrunken_representation(exception)
    }
  end

  def result_details({:error, value}) do
    %{
      type: "error",
      message: "{:error, #{Errors.Inspect.inspect(value)}}",
      value: Errors.Inspect.shrunken_representation(value)
    }
  end

  def result_details(:error) do
    %{
      type: "error",
      message: Errors.Inspect.inspect(:error)
    }
  end

  def result_details({:ok, value}) do
    %{
      type: "ok",
      message: "{:ok, #{Errors.Inspect.inspect(value)}}",
      value: Errors.Inspect.shrunken_representation(value)
    }
  end

  def result_details(:ok) do
    %{type: "ok", message: Errors.Inspect.inspect(:ok)}
  end

  defp exception_message(%mod{} = exception) when is_exception(exception) do
    if function_exported?(mod, :message, 1) or Map.has_key?(struct(mod), :message) do
      Exception.message(exception)
    else
      Logger.warning(
        "Exception module `#{inspect(mod)}` doesn't have a `message` key or implement a `message/1` callback"
      )

      inspect(exception)
    end
  end

  def user_message(reason) when is_binary(reason), do: reason

  def user_message(%WrappedError{} = error) do
    case WrappedError.unwrap(error) do
      {errors, {:error, root_reason}} ->
        context_string = Enum.map_join(errors, " => ", & &1.context)

        user_message(root_reason) <> " (happened while: #{context_string})"
    end
  end

  def user_message(exception) when is_exception(exception) do
    error_code = Errors.String.generate(8)

    Logger.error(
      "#{error_code}: Could not generate user error message. Error was: #{Errors.Inspect.inspect(exception)} (message: #{exception_message(exception)})"
    )

    "There was an error. Refer to code: #{error_code}"
  end

  def user_message(reason) do
    error_code = Errors.String.generate(8)

    Logger.error(
      "#{error_code}: Could not generate user error message. Error was: #{Errors.Inspect.inspect(reason)}"
    )

    "There was an error. Refer to code: #{error_code}"
  end

  def log(result, mode) do
    validate_result!(result)

    stacktrace = Stacktrace.calling_stacktrace()

    log_details = LogAdapter.LogDetails.new(result, stacktrace)

    adapter_mod = Application.get_env(:errors, :log_adapter, LogAdapter.Plain)

    with {level, message} <- adapter_mod.call(log_details) do
      if log_details.result_details.type == "error" || mode == :all do
        Logger.log(level, message)
      end
    end

    result
  end

  defp validate_result!(:ok), do: nil
  defp validate_result!(:error), do: nil
  defp validate_result!({:ok, _}), do: nil
  defp validate_result!({:error, _}), do: nil

  defp validate_result!(result) do
    raise ArgumentError,
          "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: #{inspect(result)}"
  end
end
