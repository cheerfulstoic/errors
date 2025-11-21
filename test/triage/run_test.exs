defmodule Triage.RunTest do
  use ExUnit.Case

  describe "run!/1" do
    test "Returns term as success" do
      start = 123
      assert Triage.run!(fn -> start * 2 end) == {:ok, 246}
    end

    test "Returns :ok as :ok" do
      assert Triage.run!(fn -> :ok end) == :ok
    end

    test "Returns success with value as success" do
      start = 123
      assert Triage.run!(fn -> {:ok, start * 2} end) == {:ok, 246}
    end

    test "Returns :error as :error" do
      assert Triage.run!(fn -> :error end) == :error
    end

    test "Returns error with value as error" do
      assert Triage.run!(fn -> {:error, "Test error"} end) == {:error, "Test error"}
    end
  end

  describe "run/1" do
    test "Returns term as success" do
      start = 123
      assert Triage.run(fn -> start * 2 end) == {:ok, 246}
    end

    test "Returns :ok as :ok" do
      assert Triage.run(fn -> :ok end) == :ok
    end

    test "Returns success with value as success" do
      start = 123
      assert Triage.run(fn -> {:ok, start * 2} end) == {:ok, 246}
    end

    test "Returns :error as :error" do
      assert Triage.run(fn -> :error end) == :error
    end

    test "Returns error with value as error" do
      assert Triage.run(fn -> {:error, "Test error"} end) == {:error, "Test error"}
    end

    test "An exception is raised" do
      {:error, %Triage.WrappedError{} = wrapped_error} =
        Triage.run(fn -> raise "boom" end)

      assert wrapped_error.message =~
               ~r<\*\* \(RuntimeError\) boom\n    \[CONTEXT\] test/triage/run_test\.exs:\d+: Triage\.RunTest\.-test run/1 An exception is raised/1-fun-0-/1>

      assert wrapped_error.result == %RuntimeError{message: "boom"}
    end
  end
end
