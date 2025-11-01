defmodule Triage do
  @moduledoc """
  Documentation for `Triage`.
  """

  alias Triage.Stacktrace
  alias Triage.WrappedError
  require Logger
  require Stacktrace

  @type result() :: :ok | :error | {:ok, term()} | {:error, term()}

  @doc """
  Wraps `t:result/0` with additional context information, leaving `:ok` results unchanged.

  Takes a result tuple and wraps error cases (`:error` or `{:error, reason}`) with
  a context string, metadata, and stacktrace info contained in `Triage.WrappedError{}`.

  If the second argument is a string, the context is set. If the second argument is a
  keyword list or a map the metadata is set.  The arity 3 version allows setting both.

  ## Examples

      iex> Triage.wrap_context(:ok, "fetching user")
      :ok

      iex> Triage.wrap_context({:ok, 42}, "fetching user")
      {:ok, 42}

      iex> Triage.wrap_context(:error, "fetching user")
      {:error, %Triage.WrappedError{}}

      iex> Triage.wrap_context({:error, :not_found}, "fetching user", %{user_id: 123})
      {:error, %Triage.WrappedError{}}

      iex> Triage.wrap_context({:error, :not_found}, %{user_id: 123})
      {:error, %Triage.WrappedError{}}
  """
  @spec wrap_context(result(), String.t() | map()) ::
          :ok | {:ok, term()} | {:error, Triage.WrappedError.t()}
  @spec wrap_context(result(), map(), keyword() | map()) ::
          :ok | {:ok, term()} | {:error, Triage.WrappedError.t()}
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

  This is the "unsafe" version that doesn't catch exceptions. Use `then/1` for
  exception handling.

  ## Parameters

    * `func` - A zero-arity function that returns a result

  ## Examples

      iex> then!(fn -> {:ok, 42} end)
      {:ok, 42}

      iex> then!(fn -> {:error, :not_found} end)
      {:error, :not_found}
  """
  @spec then!((term() -> term())) :: result()
  def then!(func) do
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

  Takes a result from a previous then and, if successful, passes the unwrapped value
  to the provided function. If the previous result was an error, short-circuits and
  returns the error without calling the function.

  This is the "unsafe" version that doesn't catch exceptions. Use `then/2` for
  exception handling.

  ## Parameters

    * `result` - The previous result (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`)
    * `func` - A function that takes the unwrapped value and returns a result

  ## Examples

      iex> then!({:ok, 5}, fn x -> {:ok, x * 2} end)
      {:ok, 10}

      iex> then!({:error, :not_found}, fn x -> {:ok, x * 2} end)
      {:error, :not_found}
  """
  @spec then!(result(), (term() -> term())) :: result()
  def then!(:ok, func) do
    case func.(nil) do
      :ok -> :ok
      {:ok, _} = result -> result
      :error -> :error
      {:error, _} = result -> result
      other -> {:ok, other}
    end
  end

  def then!({:ok, value}, func) do
    case func.(value) do
      :ok -> :ok
      {:ok, _} = result -> result
      :error -> :error
      {:error, _} = result -> result
      other -> {:ok, other}
    end
  end

  def then!(:error, _func), do: :error

  def then!({:error, _} = result, _func), do: result
  def then!(other, _), do: validate_result!(other)

  @doc """
  Executes a function that returns a result tuple, with exception handling.

  Calls the provided zero-arity function and ensures it returns a valid result.
  If the function raises an exception, it catches it and returns
  `{:error, %Triage.WrappedError{}}` with details about the exception.

  ## Parameters

    * `func` - A zero-arity function that returns a result

  ## Examples

      iex> then(fn -> {:ok, 42} end)
      {:ok, 42}

      iex> then(fn -> raise "boom" end)
      {:error, %Triage.WrappedError{}}
  """
  @spec then((term() -> term())) :: result()
  def then(func) do
    try do
      then!(func)
    rescue
      exception ->
        {:error, WrappedError.new_raised(exception, func, __STACKTRACE__)}
    end
  end

  @doc """
  Executes a function with a previous result value, with exception handling.

  Takes a result from a previous then and, if successful, passes the unwrapped value
  to the provided function. If the previous result was an error, short-circuits and
  returns the error. If the function raises an exception, it catches it and returns
  `{:error, %Triage.WrappedError{}}` with details about the exception.

  ## Parameters

    * `result` - The previous result (`:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`)
    * `func` - A function that takes the unwrapped value and returns a result

  ## Examples

      iex> then({:ok, 5}, fn x -> {:ok, x * 2} end)
      {:ok, 10}

      iex> then({:ok, 5}, fn _x -> raise "boom" end)
      {:error, %Triage.WrappedError{}}
  """
  @spec then(result(), (term() -> term())) :: result()
  def then(result, func) do
    try do
      then!(result, func)
    rescue
      exception ->
        {:error, WrappedError.new_raised(exception, func, __STACKTRACE__)}
    end
  end

  @doc """
  For dealing with `:error` cases, passing `:ok` results through unchanged.

  When given result is `{:error, reason}`, the `reason` is passed into the callback
  function. The callback function can then return a new `reason` which will be
  returned from `handle` wrapped in an `{:error, _}` tuple.

  If `:error` is the given result, `nil` will be given to the callback function.

  The callback function can also return `:ok` or `{:ok, term()}` to have the error
  be ignored and the `:ok` result will be returned instead.

  ## Examples

      iex> ping_account_server() |> Triage.handle(fn _ -> :account_server_failure end)
      {:error, :account_server_failure}

      iex> Triage.handle({:error, :unknown}, fn :unknown -> {:ok, @default_value} end)
      {:ok, ...}

      iex> Triage.handle(:ok, fn _ -> :not_used end)
      :ok

      iex> Triage.handle({:ok, ...}, fn _ -> :not_used end)
      {:ok, 42}

      iex> Triage.handle(:error, fn nil -> :handled end)
      {:error, :handled}
  """
  @spec handle(result(), (term() -> term())) :: result()
  def handle(:error, func), do: handle({:error, nil}, func)

  def handle({:error, reason}, func) do
    case func.(reason) do
      :ok ->
        :ok

      {:ok, _} = result ->
        result

      other ->
        {:error, other}
    end
  end

  def handle(result, _) do
    validate_result!(result)

    result
  end

  @doc """
  Maps a function over an enumerable, collecting successful values and short-circuiting on the first error.

  Takes an enumerable or `{:ok, enumerable}` and applies a function to each element.
  If all callbacks return success with `{:ok, value}`), `map_unless` returns
  `{:ok, [transformed_values]}`. If any call to the callback returns an error, `map_unless`
  immediately stops processing and returns that error.

  If `map_unless` is given an `:error` result for it's first argument that argument is returned
  unchanged and the callback is never called.

  This is useful when you need all transformations to succeed—if any fail, you don't want
  the partial results.

  ## Examples

      iex> Triage.map_unless(xml_docs, & xml_to_json(&1, opts))
      {:ok, [...]}

      iex> Triage.map_unless(xml_docs, & xml_to_json(&1, opts))
      {:error, ...}

      iex> Triage.map_unless(:error, fn _ -> <not called> end)
      :error

      iex> Triage.map_unless({:error, :not_found}, fn _ -> <not called end)
      {:error, :not_found}
  """
  @spec map_unless(result(), (term() -> term())) :: result()
  def map_unless({:ok, value}, func), do: map_unless(value, func)
  def map_unless(:error, _), do: :error
  def map_unless({:error, _} = error, _), do: error

  def map_unless(values, func) do
    {:ok,
     Enum.map(values, fn value ->
       case func.(value) do
         # :ok ->
         {:ok, value} ->
           value

         :error ->
           throw({:__ERRORS__, :error})

         {:error, _} = error ->
           throw({:__ERRORS__, error})
       end
     end)}
  catch
    {:__ERRORS__, result} ->
      result
  end

  @doc """
  Finds the first successful result from applying a function to enumerable elements.

  Takes an enumerable or `{:ok, enumerable}` and applies a function to each element
  The first successful result (`:ok` or `{:ok, value}`) from the callback is returned
  from `find_value` and no further iteration is done.

  If all callbacks return errors, then `{:error, [list of error reasons]}` is returned.
  For `:error` atoms in the error list, they are represented as `nil`.

  If `:error` or `{:error, reason}` is given as the first argument to `find_value`,
  it is passed through unchanged.

  This can be useful when you're trying multiple strategies or checking multiple
  values to find the first one that works.

  ## Examples

      iex> Triage.find_value(domains, &ping_domain)
      {:ok, "www.mydomain.com"}

      iex> Triage.find_value({:ok, domains}, &ping_domain)
      {:error, [:nxdomain, :timeout, :nxdomain]}

      iex> Triage.find_value(:error, fn _ -> <not called> end)
      :error

      iex> Triage.find_value({:error, :not_found}, fn _ -> <not called> end)
      {:error, :not_found}
  """
  def find_value({:ok, input}, func), do: find_value(input, func)
  def find_value(:error, _), do: :error
  def find_value({:error, _} = error, _), do: error

  def find_value(input, func) do
    errors =
      Enum.map(input, fn value ->
        case func.(value) do
          :ok -> throw({:__ERRORS__, :ok})
          {:ok, _} = result -> throw({:__ERRORS__, result})
          :error -> nil
          {:error, reason} -> reason
        end
      end)

    {:error, errors}
  catch
    {:__ERRORS__, result} ->
      result
  end

  @doc """
  Validates that all elements in an enumerable pass a validation function.

  Takes an enumerable or `{:ok, enumerable}` and applies a callback function to each
  element. If all callbacks return `:ok` or `{:ok, value}` then `:ok` is returned.

  If any callback returns an error, immediately stops processing and returns that error.

  If `:error` or `{:error, reason}` are given as the first argument, they are returned
  unchanged. Note that even if callbacks return `{:ok, value}`, the values are discarded
  and only `:ok` is returned — this function is for validation, not transformation.
  See `map_unless/2` if you need transformation which short-circuits.

  This is useful when you need to validate that all items in a collection meet certain
  criteria before proceeding with subsequent operations.

  ## Examples

      iex> Triage.all(emails, &check_valid_email)
      :ok

      iex> Triage.all({:ok, emails}, &check_valid_email)
      {:error, :invalid_hostname}

      iex> Triage.all(:error, fn _ -> <not called> end)
      :error

      iex> Triage.all({:error, :not_found}, fn _ -> <not called> end)
      {:error, :not_found}
  """
  def all({:ok, input}, func), do: all(input, func)
  def all(:error, _), do: :error
  def all({:error, _} = error, _), do: error

  def all(input, func) do
    for value <- input do
      case func.(value) do
        :ok ->
          nil

        {:ok, _} ->
          nil

        :error ->
          throw({:__ERRORS__, :error})

        {:error, _} = error ->
          throw({:__ERRORS__, error})

        other ->
          validate_result!(other, "Callback return")
      end
    end

    :ok
  catch
    # Wrapping throw so that callback throws will not be caught by us
    {:__ERRORS__, error} ->
      error
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

  @doc false
  def result_details({:error, %WrappedError{} = exception}) do
    errors = WrappedError.unwrap(exception)
    last_error = List.last(errors)

    metadata =
      Enum.reduce(errors, %{}, fn error, metadata ->
        Map.merge(metadata, error.metadata)
      end)

    result_details(last_error.result)
    |> Map.put(:metadata, metadata)
    |> Map.put(:message, Exception.message(exception))
  end

  def result_details({:error, %mod{} = exception}) when is_exception(exception) do
    %{
      type: "error",
      mod: mod,
      reason: Triage.JSON.Shrink.shrink(exception),
      message:
        "{:error, #{Triage.Inspect.inspect(exception)}} (message: #{exception_message(exception)})"
    }
  end

  def result_details({:error, reason}) do
    %{
      type: "error",
      message: "{:error, #{Triage.Inspect.inspect(reason)}}",
      reason: Triage.JSON.Shrink.shrink(reason)
    }
  end

  def result_details(:error) do
    %{
      type: "error",
      message: Triage.Inspect.inspect(:error)
    }
  end

  def result_details({:ok, value}) do
    %{
      type: "ok",
      message: "{:ok, #{Triage.Inspect.inspect(value)}}",
      value: Triage.JSON.Shrink.shrink(value)
    }
  end

  def result_details(:ok) do
    %{type: "ok", message: Triage.Inspect.inspect(:ok)}
  end

  # If `result` isn't :ok/:error/{:ok, _}/{:error, _} then it was a raised exception
  def result_details(%mod{} = exception) when is_exception(exception) do
    %{
      type: "raise",
      message: "** (#{inspect(mod)}) #{Exception.message(exception)}",
      reason: Triage.JSON.Shrink.shrink(exception)
    }
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

  When the `reason` is a string, the string error message is returned.

  When the `reason` is `t:Triage.WrappedError.t/0` it unwraps the error chain and includes context information in the message.

  For exceptions and unknown error types, it
   * generates a unique error code
   * logs the error code with full error details
   * returns a generic error to the user with the error code that the user can report

  ## Parameters

    * `reason` - The error to convert (string, exception, `%Triage.WrappedError{}`, or any other value)

  ## Examples

      iex> user_message("Invalid email")
      "Invalid email"

      iex> user_message(%Triage.WrappedError{})
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
    error_code = Triage.String.generate(8)

    Logger.error(
      "#{error_code}: Could not generate user error message. Error was: #{Triage.Inspect.inspect(exception)} (message: #{exception_message(exception)})"
    )

    "There was an error. Refer to code: #{error_code}"
  end

  def user_message(reason) do
    error_code = Triage.String.generate(8)

    Logger.error(
      "#{error_code}: Could not generate user error message. Error was: #{Triage.Inspect.inspect(reason)}"
    )

    "There was an error. Refer to code: #{error_code}"
  end

  @doc """
  Logs a result tuple and returns it unchanged.

  Takes a result and logs it using the configured log adapter. By default, only
  errors are logged. Use `mode: :all` to log both successes and errors.

  See [this guide](logging-json.html) for information about
  logging with JSON

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

    {message, result_details} = Map.pop(result_details(result), :message)

    if result_details.type in ~w[error raise] || mode == :all do
      level = if(result_details.type in ~w[error raise], do: :error, else: :info)

      stacktrace_line =
        stacktrace
        |> Stacktrace.most_relevant_entry()
        |> Stacktrace.format_file_line()

      parts_string =
        [stacktrace_line, message]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(": ")

      {metadata, result_details} = Map.pop(result_details, :metadata, %{})

      metadata = Map.put(metadata, :errors_result_details, result_details)

      Logger.log(level, "[RESULT] #{parts_string}", metadata)
    end

    result
  end

  @doc """
  Checks if a result is a success (`:ok` or `{:ok, term()}`).

  Returns `true` if the result is `:ok` or `{:ok, term()}`, `false` if it's
  `:error` or `{:error, term()}`. Raises `ArgumentError` for any other value.

  ## Examples

      iex> Triage.ok?(:ok)
      true

      iex> Triage.ok?({:ok, 42})
      true

      iex> Triage.ok?(:error)
      false

      iex> Triage.ok?({:error, :not_found})
      false
  """
  def ok?(:ok), do: true
  def ok?({:ok, _}), do: true
  def ok?(:error), do: false
  def ok?({:error, _}), do: false
  def ok?(result), do: validate_result!(result)

  @doc """
  Checks if a result is an error (`:error` or `{:error, term()}`).

  Returns `true` if the result is `:error` or `{:error, term()}`, `false` if it's
  `:ok` or `{:ok, term()}`. Raises `ArgumentError` for any other value.

  ## Examples

      iex> Triage.error?(:error)
      true

      iex> Triage.error?({:error, :not_found})
      true

      iex> Triage.error?(:ok)
      false

      iex> Triage.error?({:ok, 42})
      false
  """
  def error?(:ok), do: false
  def error?({:ok, _}), do: false
  def error?(:error), do: true
  def error?({:error, _}), do: true
  def error?(result), do: validate_result!(result)

  defp validate_result!(:ok), do: nil
  defp validate_result!(:error), do: nil
  defp validate_result!({:ok, _}), do: nil
  defp validate_result!({:error, _}), do: nil

  defp validate_result!(result, label \\ "Argument") do
    raise ArgumentError,
          "#{label} must be {:ok, _} / :ok / {:error, _} / :error, got: #{inspect(result)}"
  end
end
