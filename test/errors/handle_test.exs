defmodule Errors.HandleTest do
  use ExUnit.Case

  describe "handle/1" do
    test "requires result to be a result" do
      func = fn :unknown -> :not_found end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: :ook",
                   fn ->
                     Errors.handle(:ook, func) == :ok
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     Errors.handle(123, func) == :ok
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: {:wow, 246}",
                   fn ->
                     Errors.handle({:wow, 246}, func) == {:ok, 246}
                   end
    end

    test "passes through successes unchanged" do
      func = fn :unknown -> :not_found end

      assert Errors.handle(:ok, func) == :ok
      assert Errors.handle({:ok, 246}, func) == {:ok, 246}
    end

    test ":error atom" do
      func = fn
        :unknown -> :not_found
        :server_timed_out -> :timeout
        nil -> :wow_nil_cool
      end

      assert Errors.handle(:error, func) == {:error, :wow_nil_cool}

      func = fn
        :unknown -> :not_found
        :server_timed_out -> :timeout
      end

      assert_raise FunctionClauseError, fn ->
        Errors.handle(:error, func)
      end
    end

    test "error tuples are handled by the callback" do
      func = fn
        :unknown -> :not_found
        :server_timed_out -> :timeout
      end

      assert Errors.handle({:error, :unknown}, func) == {:error, :not_found}
      assert Errors.handle({:error, :server_timed_out}, func) == {:error, :timeout}

      assert_raise FunctionClauseError, fn ->
        Errors.handle({:error, :something_else}, func)
      end
    end

    test "returning success results on error" do
      func = fn
        :unknown -> :not_found
        :server_timed_out -> {:ok, :default_value}
        :whatever -> :ok
      end

      assert Errors.handle({:error, :unknown}, func) == {:error, :not_found}
      assert Errors.handle({:error, :server_timed_out}, func) == {:ok, :default_value}
      assert Errors.handle({:error, :whatever}, func) == :ok
    end
  end
end
