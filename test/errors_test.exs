defmodule ErrorsTest do
  use ExUnit.Case
  alias Errors.WrappedError

  describe ".wrap_context" do
    test "with ok result returns the same" do
      assert Errors.wrap_context({:ok, 42}, "doing something", %{foo: :bar}) == {:ok, 42}

      assert Errors.wrap_context(:ok, "doing something", %{foo: :bar}) == :ok
    end

    test "with {:error, _} wraps the error in a WrappedError" do
      # keyword list
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context({:error, :some_reason}, "doing something", foo: :bar)

      assert wrapped_error.reason == :some_reason
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {ErrorsTest,
              :"test .wrap_context with {:error, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/errors_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # map
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context({:error, :some_reason}, "doing something", %{foo: :bar})

      assert wrapped_error.reason == :some_reason
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {ErrorsTest,
              :"test .wrap_context with {:error, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/errors_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # no context
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context({:error, :some_reason}, foo: :bar)

      assert wrapped_error.reason == :some_reason
      assert wrapped_error.context == nil
      assert wrapped_error.metadata == %{foo: :bar}

      assert {ErrorsTest,
              :"test .wrap_context with {:error, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/errors_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)
    end

    test "with :error wraps the error in a WrappedError" do
      # keyword list
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context(:error, "doing something", foo: :bar)

      assert wrapped_error.reason == nil
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {ErrorsTest, :"test .wrap_context with :error wraps the error in a WrappedError", 1,
              [file: ~c"test/errors_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # map
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context(:error, "doing something", %{foo: :bar})

      assert wrapped_error.reason == nil
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {ErrorsTest, :"test .wrap_context with :error wraps the error in a WrappedError", 1,
              [file: ~c"test/errors_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # no context
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context(:error, foo: :bar)

      assert wrapped_error.reason == nil
      assert wrapped_error.context == nil
      assert wrapped_error.metadata == %{foo: :bar}

      assert {ErrorsTest, :"test .wrap_context with :error wraps the error in a WrappedError", 1,
              [file: ~c"test/errors_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)
    end
  end
end
