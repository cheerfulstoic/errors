defmodule Errors do
  @moduledoc """
  Documentation for `Errors`.
  """

  alias Errors.Stacktrace
  require Logger
  require Stacktrace

  def wrap_context(:ok, _meta), do: :ok

  def wrap_context({:ok, result}, _meta) do
    {:ok, result}
  end

  def wrap_context(:error, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, Errors.WrappedError.new(:error, nil, stacktrace, metadata)}
  end

  def wrap_context({:error, reason}, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, Errors.WrappedError.new({:error, reason}, nil, stacktrace, metadata)}
  end

  def wrap_context(result, context, meta \\ %{})

  def wrap_context(:ok, _context, _meta), do: :ok

  def wrap_context({:ok, result}, _context, _meta) do
    {:ok, result}
  end

  def wrap_context(:error, context, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, Errors.WrappedError.new(:error, context, stacktrace, metadata)}
  end

  def wrap_context({:error, reason}, context, metadata) do
    stacktrace = Stacktrace.calling_stacktrace()

    {:error, Errors.WrappedError.new({:error, reason}, context, stacktrace, metadata)}
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
  #       result_metadata(reason)
  #     )
  #   )
  #
  #   {:error}
  # end

  def result_metadata({:error, %Errors.WrappedError{} = exception}) do
    %{
      message: Exception.message(exception)
    }
  end

  def result_metadata({:error, %mod{} = exception}) when is_exception(exception) do
    %{
      mod: mod,
      message: "{:error, %#{inspect(mod)}{...}} (message: #{exception_message(exception)})"
    }
  end

  def result_metadata(reason), do: %{message: inspect(reason)}

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

  def log(result, mode) do
    stacktrace_line =
      Stacktrace.calling_stacktrace()
      |> Stacktrace.most_relevant_entry()
      |> Stacktrace.format_file_line()

    log_spec =
      case result do
        :error ->
          %{message: message} = result_metadata(result)

          {:error, "#{message}"}

        {:error, _} ->
          %{message: message} = result_metadata(result)

          {:error, "#{message}"}

        :ok ->
          if mode == :all do
            {:info, ":ok"}
          end

        {:ok, value} ->
          if mode == :all do
            {:info, "{:ok, #{inspect(value)}}"}
          end

        _ ->
          # TODO: Should we always raise?
          raise ArgumentError,
                "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: #{inspect(result)}"
      end

    with {level, message} <- log_spec do
      parts_string =
        [stacktrace_line, message]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")

      Logger.log(level, "[RESULT] #{parts_string}")
    end

    result
  end
end
