defmodule Errors do
  @moduledoc """
  Documentation for `Errors`.
  """

  alias Errors.Stacktrace
  require Logger
  require Stacktrace

  def wrap_context(:ok, context, meta \\ %{}), do: :ok

  def wrap_context(:ok, _context, _meta), do: :ok

  def wrap_context({:ok, result}, _context, _meta) do
    {:ok, result}
  end

  def wrap_context(:error, context, metadata) do
    # Stacktrace.calling_stacktrace()

    {:error, Errors.WrappedError.new(:error, context, metadata)}
  end

  def wrap_context({:error, reason}, context, metadata) do
    {:error, Errors.WrappedError.new({:error, reason}, context, metadata)}
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
  #       reason_metadata(reason)
  #     )
  #   )
  #
  #   {:error}
  # end
  #
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
        "Exception module `#{inspect(mod)}` doesn't have a `message` key or implement a `message/1` callback"
      )

      inspect(exception)
    end
  end

  def log(result, mode) do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    stacktrace_line =
      Stacktrace.calling_stacktrace()
      |> Stacktrace.most_relevant_entry()
      |> format_file_line()

    log_spec =
      case result do
        :error ->
          {:error, ":error"}

        {:error, %Errors.WrappedError{} = reason} ->
          {:error, Exception.message(reason)}

        {:error, reason} ->
          case reason_metadata(reason) do
            %{mod: mod, message: message} ->
              {:error, "{:error, %#{inspect(mod)}{...}} (message: #{message})"}

            %{message: message} ->
              {:error, "{:error, #{message}}"}
          end

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
      Logger.log(level, "[RESULT] #{stacktrace_line} #{message}")
    end

    result
  end

  defp format_file_line({_mod, _func, _arity, location}) do
    file = Keyword.get(location, :file)
    line = Keyword.get(location, :line)

    cond do
      is_nil(file) -> ""
      is_nil(line) or line == 0 -> "(#{file})"
      true -> "(#{file}:#{line})"
    end
  end
end
