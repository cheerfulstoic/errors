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

      # map
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context({:error, :some_reason}, "doing something", %{foo: :bar})

      assert wrapped_error.reason == :some_reason
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}
    end

    test "with :error wraps the error in a WrappedError" do
      # keyword list
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context(:error, "doing something", foo: :bar)

      assert wrapped_error.reason == nil
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}

      # map
      {:error, %WrappedError{} = wrapped_error} =
        Errors.wrap_context(:error, "doing something", %{foo: :bar})

      assert wrapped_error.reason == nil
      assert wrapped_error.context == "doing something"
      assert wrapped_error.metadata == %{foo: :bar}
    end
  end
end
