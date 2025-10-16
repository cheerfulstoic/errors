defmodule Errors.IntegrationTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    Application.delete_env(:errors, :app)
    Application.delete_env(:errors, :log_adapter)

    on_exit(fn ->
      Application.delete_env(:errors, :app)
      Application.delete_env(:errors, :log_adapter)
    end)

    :ok
  end

  describe "step!/1 with wrap_context" do
    test "wraps error with context" do
      result =
        Errors.step!(fn -> {:error, "database connection failed"} end)
        |> Errors.wrap_context("Fetching user")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "Fetching user"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.result == {:error, "database connection failed"}
    end

    test "wraps error in multi-step chain" do
      result =
        Errors.step!(fn -> {:ok, 10} end)
        |> Errors.step!(fn _ -> {:error, "calculation failed"} end)
        |> Errors.step!(fn _ -> raise "Should not be called" end)
        |> Errors.wrap_context("Final calculation")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "Final calculation"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.result == {:error, "calculation failed"}
    end
  end

  describe "step!/2 with wrap_context" do
    test "wraps error with context" do
      result =
        {:error, "user not found"}
        |> Errors.step!(fn _ -> raise "Should not be called" end)
        |> Errors.wrap_context("Fetching user")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "Fetching user"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.result == {:error, "user not found"}
    end

    test "chains multiple wrap_context calls" do
      result =
        {:ok, "user@example.com"}
        |> Errors.step!(fn email -> {:error, "invalid email: #{email}"} end)
        |> Errors.wrap_context("first")
        |> Errors.step!(fn _ -> raise "Should not be called" end)
        |> Errors.wrap_context("second")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "second"
      assert wrapped_error.metadata == %{}

      assert {:error, %Errors.WrappedError{} = second_wrapped_error} = wrapped_error.result
      assert second_wrapped_error.context == "first"
      assert second_wrapped_error.metadata == %{}
      assert second_wrapped_error.result == {:error, "invalid email: user@example.com"}
    end
  end

  describe "step/2 with wrap_context" do
    test "wraps caught exception with context" do
      func = fn _ -> raise ArgumentError, "invalid value" end

      result =
        {:ok, 10}
        |> Errors.step(func)
        |> Errors.wrap_context("Processing payment")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "Processing payment"
      assert wrapped_error.metadata == %{}

      assert {:error, %Errors.WrappedError{} = second_wrapped_error} = wrapped_error.result
      assert second_wrapped_error.context == func
      assert second_wrapped_error.metadata == %{}

      assert {Errors.IntegrationTest,
              :"-test step/2 with wrap_context wraps caught exception with context/1-fun-0-", _,
              [file: ~c"test/errors/integration_test.exs", line: _]} =
               List.first(second_wrapped_error.stacktrace)

      assert %ArgumentError{message: "invalid value"} = second_wrapped_error.result
      assert %ArgumentError{message: "invalid value"} = second_wrapped_error.reason
    end

    test "wraps error with context" do
      result =
        {:error, "user not found"}
        |> Errors.step(fn _ -> raise "Should not be called" end)
        |> Errors.wrap_context("Fetching user")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "Fetching user"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.result == {:error, "user not found"}
    end

    test "chains multiple wrap_context calls" do
      result =
        {:ok, "user@example.com"}
        |> Errors.step(fn email -> {:error, "invalid email: #{email}"} end)
        |> Errors.wrap_context("first")
        |> Errors.step(fn _ -> raise "Should not be called" end)
        |> Errors.wrap_context("second")

      assert {:error, %Errors.WrappedError{} = wrapped_error} = result
      assert wrapped_error.context == "second"
      assert wrapped_error.metadata == %{}

      assert {:error, %Errors.WrappedError{} = second_wrapped_error} = wrapped_error.result
      assert second_wrapped_error.context == "first"
      assert second_wrapped_error.metadata == %{}
      assert second_wrapped_error.result == {:error, "invalid email: user@example.com"}
    end
  end

  describe "log with wrapped errors" do
    test "logs simple wrapped error with context" do
      log =
        capture_log([level: :error], fn ->
          result =
            Errors.step!(fn -> {:error, "database timeout"} end)
            |> Errors.wrap_context("Fetching user data")
            |> Errors.log()

          assert {:error, %Errors.WrappedError{}} = result
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/integration_test\.exs:\d+: {:error, "database timeout"}
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: Fetching user data>
    end

    test "logs nested wrapped errors from step/2 exception" do
      log =
        capture_log([level: :error], fn ->
          result =
            {:ok, 100}
            |> Errors.step(&Errors.TestHelper.raise_argument_error/1)
            |> Errors.wrap_context("Processing payment")
            |> Errors.log()

          assert {:error, %Errors.WrappedError{}} = result
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/integration_test\.exs:\d+: \*\* \(ArgumentError\) amount too high
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: Processing payment
    \[CONTEXT\] lib/errors/test_helper.ex:\d+: Errors\.TestHelper\.raise_argument_error/1>
    end

    test "logs deeply nested contexts" do
      log =
        capture_log([level: :error], fn ->
          result =
            {:ok, "test@example.com"}
            |> Errors.step!(fn email -> {:error, "invalid domain for #{email}"} end)
            |> Errors.wrap_context("Validating email")
            |> Errors.wrap_context("User registration")
            |> Errors.wrap_context("API endpoint: /users")
            |> Errors.log()

          assert {:error, %Errors.WrappedError{}} = result
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/integration_test\.exs:\d+: {:error, "invalid domain for test@example.com"}
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: API endpoint: /users
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: User registration
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: Validating email>
    end

    test "does not log successes with :errors mode" do
      log =
        capture_log([level: :error], fn ->
          result = {:ok, "success"} |> Errors.log()
          assert result == {:ok, "success"}
        end)

      assert log == ""
    end

    test "logs successes with :all mode" do
      log =
        capture_log([level: :info], fn ->
          result = {:ok, 42} |> Errors.log(:all)
          assert result == {:ok, 42}
        end)

      assert log =~ ~r<\[RESULT\] test/errors/integration_test\.exs:\d+: {:ok, 42}>
    end

    test "logs step/2 chain with exception and wrap_context" do
      log =
        capture_log([level: :error], fn ->
          result =
            {:ok, 5}
            |> Errors.step(fn x -> x * 2 end)
            |> Errors.step(fn x -> x + 3 end)
            |> Errors.step(fn _ -> raise RuntimeError, "unexpected failure" end)
            |> Errors.wrap_context("Data processing pipeline")
            |> Errors.log()

          assert {:error, %Errors.WrappedError{}} = result
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/integration_test\.exs:\d+: \*\* \(RuntimeError\) unexpected failure
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: Data processing pipeline
    \[CONTEXT\] test/errors/integration_test\.exs:\d+: Errors\.IntegrationTest\.-test log with wrapped errors logs step/2 chain with exception and wrap_context/1-fun-0-/1>
    end
  end

  test "" do
    log =
      capture_log([level: :error], fn ->
        {:ok, "123u"}
        # Raises if not a valid integer
        |> Errors.step(&String.to_integer/1)
        |> Errors.log()
      end)

    assert log =~
             ~r<\[RESULT\] lib/ex_unit/capture_log\.ex:\d+: \*\* \(ArgumentError\) errors were found at the given arguments:

  \* 1st argument: not a textual representation of an integer

    \[CONTEXT\] :erlang\.binary_to_integer/1>

    Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

    log =
      capture_log([level: :error], fn ->
        {:ok, "123u"}
        # Raises if not a valid integer
        |> Errors.step(&String.to_integer/1)
        |> Errors.log()
      end)

    [_, json] = Regex.run(~r/\[error\] (.*)/, log)

    data = Jason.decode!(json)

    assert data["source"] == "Errors"
    assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

    assert data["result_details"]["type"] == "error"

    assert data["result_details"]["message"] ==
             "** (ArgumentError) errors were found at the given arguments:\n\n  * 1st argument: not a textual representation of an integer\n\n    [CONTEXT] :erlang.binary_to_integer/1"

    assert %{
             "__struct__" => "ArgumentError",
             "__message__" =>
               "errors were found at the given arguments:\n\n  * 1st argument: not a textual representation of an integer\n"
           } = data["result_details"]["value"]["__root_reason__"]
  end
end
