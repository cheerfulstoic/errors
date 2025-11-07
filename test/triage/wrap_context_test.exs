defmodule Triage.WrapContextTest do
  use ExUnit.Case
  alias Triage.WrappedError

  describe ".wrap_context" do
    test "with ok result returns the same" do
      # context and metadata
      assert Triage.wrap_context({:ok, 42}, "doing something", %{foo: :bar}) == {:ok, 42}

      assert Triage.wrap_context({:ok, 42, :foo}, "doing something", %{foo: :bar}) ==
               {:ok, 42, :foo}

      assert Triage.wrap_context(:ok, "doing something", %{foo: :bar}) == :ok

      # context
      assert Triage.wrap_context({:ok, 42}, "doing something") == {:ok, 42}

      assert Triage.wrap_context({:ok, 42, :foo}, "doing something") ==
               {:ok, 42, :foo}

      assert Triage.wrap_context(:ok, "doing something") == :ok

      # metadata
      assert Triage.wrap_context({:ok, 42}, %{foo: :bar}) == {:ok, 42}

      assert Triage.wrap_context({:ok, 42, :foo}, %{foo: :bar}) ==
               {:ok, 42, :foo}

      assert Triage.wrap_context(:ok, %{foo: :bar}) == :ok
    end

    test "with {:error, _} wraps the error in a WrappedError" do
      # keyword list
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context({:error, :some_reason}, "doing something", foo: :bar)

      assert wrapped_error.result == {:error, :some_reason}
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with {:error, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # map
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context({:error, :some_reason}, "doing something", %{foo: :bar})

      assert wrapped_error.result == {:error, :some_reason}
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with {:error, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # no context
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context({:error, :some_reason}, foo: :bar)

      assert wrapped_error.result == {:error, :some_reason}
      assert wrapped_error.context == nil
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with {:error, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)
    end

    test "with {:error, _, _} wraps the error in a WrappedError" do
      # context and metadata
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context({:error, :some_reason, :foo}, "doing something", foo: :bar)

      assert wrapped_error.result == {:error, :some_reason, :foo}
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with {:error, _, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # context
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context({:error, :some_reason, :foo}, "doing something")

      assert wrapped_error.result == {:error, :some_reason, :foo}
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with {:error, _, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # metadata
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context({:error, :some_reason, :foo}, foo: :bar)

      assert wrapped_error.result == {:error, :some_reason, :foo}
      assert wrapped_error.context == nil
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with {:error, _, _} wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)
    end

    test "with :error wraps the error in a WrappedError" do
      # keyword list
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context(:error, "doing something", foo: :bar)

      assert wrapped_error.result == :error
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with :error wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # map
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context(:error, "doing something", %{foo: :bar})

      assert wrapped_error.result == :error
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with :error wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)

      # no context
      {:error, %WrappedError{} = wrapped_error} =
        Triage.wrap_context(:error, foo: :bar)

      assert wrapped_error.result == :error
      assert wrapped_error.context == nil
      assert wrapped_error.metadata == %{foo: :bar}

      assert {Triage.WrapContextTest,
              :"test .wrap_context with :error wraps the error in a WrappedError", 1,
              [file: ~c"test/triage/wrap_context_test.exs", line: _]} =
               List.first(wrapped_error.stacktrace)
    end
  end
end
