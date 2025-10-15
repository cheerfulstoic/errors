defmodule Errors.StepTest do
  use ExUnit.Case

  describe "step!/1" do
    test "Returns term as success" do
      start = 123
      assert Errors.step!(fn -> start * 2 end) == {:ok, 246}
    end

    test "Returns :ok as :ok" do
      assert Errors.step!(fn -> :ok end) == :ok
    end

    test "Returns success with value as success" do
      start = 123
      assert Errors.step!(fn -> {:ok, start * 2} end) == {:ok, 246}
    end

    test "Returns :error as :error" do
      assert Errors.step!(fn -> :error end) == :error
    end

    test "Returns error with value as error" do
      assert Errors.step!(fn -> {:error, "Test error"} end) == {:error, "Test error"}
    end
  end
end
