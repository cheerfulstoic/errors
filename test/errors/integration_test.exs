defmodule Errors.IntegrationTest do
  use ExUnit.Case

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
      assert second_wrapped_error.result == nil
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
end
