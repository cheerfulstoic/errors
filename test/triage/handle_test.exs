defmodule Triage.HandleTest do
  use ExUnit.Case

  describe "handle/1" do
    test "requires result to be a result" do
      func = fn :unknown -> :not_found end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: :ook",
                   fn ->
                     Triage.handle(:ook, func) == :ok
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     Triage.handle(123, func) == :ok
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: {:wow, 246}",
                   fn ->
                     Triage.handle({:wow, 246}, func) == {:ok, 246}
                   end
    end

    test "passes through successes unchanged" do
      func = fn :unknown -> :not_found end

      assert Triage.handle(:ok, func) == :ok
      assert Triage.handle({:ok, 246}, func) == {:ok, 246}
    end

    test ":error atom" do
      func = fn
        :unknown -> :not_found
        :server_timed_out -> :timeout
        nil -> :wow_nil_cool
      end

      assert Triage.handle(:error, func) == {:error, :wow_nil_cool}

      func = fn
        :unknown -> :not_found
        :server_timed_out -> :timeout
      end

      assert_raise FunctionClauseError, fn ->
        Triage.handle(:error, func)
      end
    end

    test "error tuples are handled by the callback" do
      func = fn
        :unknown -> :not_found
        :server_timed_out -> :timeout
      end

      assert Triage.handle({:error, :unknown}, func) == {:error, :not_found}
      assert Triage.handle({:error, :server_timed_out}, func) == {:error, :timeout}

      assert_raise FunctionClauseError, fn ->
        Triage.handle({:error, :something_else}, func)
      end
    end

    test "returning success results on error" do
      func = fn
        :unknown -> :not_found
        :server_timed_out -> {:ok, :default_value}
        :whatever -> :ok
      end

      assert Triage.handle({:error, :unknown}, func) == {:error, :not_found}
      assert Triage.handle({:error, :server_timed_out}, func) == {:ok, :default_value}
      assert Triage.handle({:error, :whatever}, func) == :ok
    end
  end
end
