defmodule Errors do
  @moduledoc """
  Documentation for `Errors`.
  """

  alias Errors.Stacktrace
  alias Errors.LogAdapter
  alias Errors.WrappedError
  require Logger
  require Stacktrace

  @doc """
  Wraps error results with additional context information, leaving successful results unchanged.

  Takes a result tuple and wraps error cases (`:error` or `{:error, reason}`) with
  context information and metadata, returning `{:error, %Errors.WrappedError{}}`. Success
  cases (`:ok` or `{:ok, value}`) are passed through unchanged.

  ## Parameters

    * `result` - The result to potentially wrap (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`)
    * `context` - Either a string describing the context or a map/keyword list of metadata

  ## Examples

      iex> Errors.wrap_context({:ok, 42}, "fetching user")
      {:ok, 42}

      iex> Errors.wrap_context(:error, "fetching user")
      {:error, %Errors.WrappedError{}}

      iex> Errors.wrap_context({:error, :not_found}, "fetching user", %{user_id: 123})
      {:error, %Errors.WrappedError{}}

      iex> Errors.wrap_context({:error, :not_found}, %{user_id: 123})
      {:error, %Errors.WrappedError{}}
  """
  def wrap_context(:ok, _meta), do: :ok

  def wrap_context({:ok, result}, _meta) do
    {:ok, result}
  end

  def wrap_context(result, context) when is_binary(context) do
    wrap_context(result, context, %{})
  end

  def wrap_context(result, metadata) when is_map(metadata) or is_list(metadata) do
    wrap_context(result, nil, metadata)
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

  @doc """
  Executes a function that returns a result tuple, without exception handling.

  Calls the provided zero-arity function and chehcks that it returns a result
  (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`). If the function returns
  any other value, it wraps it in `{:ok, value}`.

  This is the "unsafe" version that doesn't catch exceptions. Use `step/1` for
  exception handling.

  ## Parameters

    * `func` - A zero-arity function that returns a result

  ## Examples

      iex> step!(fn -> {:ok, 42} end)
      {:ok, 42}

      iex> step!(fn -> {:error, :not_found} end)
      {:error, :not_found}
  """
  def step!(func) do
    case func.() do
      :ok -> :ok
      {:ok, _} = result -> result
      :error -> :error
      {:error, _} = result -> result
      other -> {:ok, other}
    end
  end

  @doc """
  Executes a function with a previous result value, without exception handling.

  Takes a result from a previous step and, if successful, passes the unwrapped value
  to the provided function. If the previous result was an error, short-circuits and
  returns the error without calling the function.

  This is the "unsafe" version that doesn't catch exceptions. Use `step/2` for
  exception handling.

  ## Parameters

    * `result` - The previous result (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`)
    * `func` - A function that takes the unwrapped value and returns a result

  ## Examples

      iex> step!({:ok, 5}, fn x -> {:ok, x * 2} end)
      {:ok, 10}

      iex> step!({:error, :not_found}, fn x -> {:ok, x * 2} end)
      {:error, :not_found}
  """
  def step!(:ok, func) do
    case func.(nil) do
      :ok -> :ok
      {:ok, _} = result -> result
      :error -> :error
      {:error, _} = result -> result
      other -> {:ok, other}
    end
  end

  def step!({:ok, value}, func) do
    case func.(value) do
      :ok -> :ok
      {:ok, _} = result -> result
      :error -> :error
      {:error, _} = result -> result
      other -> {:ok, other}
    end
  end

  def step!(:error, _func), do: :error

  def step!({:error, _} = result, _func), do: result
  def step!(other, _), do: validate_result!(other)

  @doc """
  Executes a function that returns a result tuple, with exception handling.

  Calls the provided zero-arity function and ensures it returns a valid result.
  If the function raises an exception, it catches it and returns
  `{:error, %Errors.WrappedError{}}` with details about the exception.

  ## Parameters

    * `func` - A zero-arity function that returns a result

  ## Examples

      iex> step(fn -> {:ok, 42} end)
      {:ok, 42}

      iex> step(fn -> raise "boom" end)
      {:error, %Errors.WrappedError{}}
  """
  def step(func) do
    try do
      step!(func)
    rescue
      exception ->
        {:error, WrappedError.new_raised(exception, func, __STACKTRACE__)}
    end
  end

  @doc """
  Executes a function with a previous result value, with exception handling.

  Takes a result from a previous step and, if successful, passes the unwrapped value
  to the provided function. If the previous result was an error, short-circuits and
  returns the error. If the function raises an exception, it catches it and returns
  `{:error, %Errors.WrappedError{}}` with details about the exception.

  ## Parameters

    * `result` - The previous result (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`)
    * `func` - A function that takes the unwrapped value and returns a result

  ## Examples

      iex> step({:ok, 5}, fn x -> {:ok, x * 2} end)
      {:ok, 10}

      iex> step({:ok, 5}, fn _x -> raise "boom" end)
      {:error, %Errors.WrappedError{}}
  """
  def step(result, func) do
    # {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
    # dbg(stacktrace)
    # stacktrace = Stacktrace.calling_stacktrace()
    # dbg(stacktrace)

    # telemetry_step_span(func, input, context, fn ->
    try do
      step!(result, func)
    rescue
      exception ->
        # dbg(__STACKTRACE__)

        {:error, WrappedError.new_raised(exception, func, __STACKTRACE__)}
        # catch
        #   :throw, value ->
        #     {:error, "Value was thrown: #{inspect(value)}"}
    end

    # |> case do
    #   {:ok, new_state} ->
    #     {:ok, new_state}
    #
    #   {:error, error_value} ->
    #     if wrap_step_function_errors?() do
    #       {:error, StepFunctionError.exception({func, error_value, nil, false})}
    #     else
    #       {:error, error_value}
    #     end
    #
    #   other ->
    #     {:error,
    #      Error.exception(
    #        {func, context,
    #         "Value other than {:ok, _} or {:error, _} returned for step function: #{inspect(other)}"}
    #      )}
    # end
    # end)
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

  # If `result` isn't :ok/:error/{:ok, _}/{:error, _} then it was a raised exception
  def result_details(%mod{} = exception) when is_exception(exception) do
    %{type: "raise", message: "** (#{inspect(mod)}) #{Exception.message(exception)}"}
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

  @doc """
  Generates a user-friendly error message from various error types.

  Converts errors into human-readable messages suitable for displaying to end users.
  For wrapped errors, it unwraps the error chain and includes context information in the message.
  For exceptions and unknown error types, it generates a unique error code and logs
  the full error details for debugging.

  ## Parameters

    * `reason` - The error to convert (string, exception, `%Errors.WrappedError{}`, or any value)

  ## Examples

      iex> user_message("Invalid email")
      "Invalid email"

      iex> user_message(%Errors.WrappedError{})
      "not found (happened while: fetching user => validating email)"

      iex> user_message(%RuntimeError{message: "boom"})
      "There was an error. Refer to code: ABC12345"

      Log generated:
      ABC12345: Could not generate user error message. Error was: #RuntimeError<...> (message: boom)
  """
  def user_message(reason) when is_binary(reason), do: reason

  def user_message(%WrappedError{} = error) do
    errors = WrappedError.unwrap(error)
    last_error = List.last(errors)
    context_string = Enum.map_join(errors, " => ", & &1.context)

    user_message(last_error.reason) <> " (happened while: #{context_string})"
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

  @doc """
  Logs a result tuple and returns it unchanged.

  Takes a result and logs it using the configured log adapter. By default, only
  errors are logged. Use `mode: :all` to log both successes and errors.

  ## Parameters

    * `result` - The result to log (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`)
    * `mode` - Either `:errors` (default, logs only errors) or `:all` (logs all results)
  """
  def log(result, mode \\ :errors) do
    validate_result!(result)

    if mode not in [:errors, :all] do
      raise ArgumentError, "mode must be either :errors or :all (got: #{inspect(mode)})"
    end

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
