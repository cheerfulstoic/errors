defmodule Errors.FindValueTest do
  use ExUnit.Case

  describe "find_value/2" do
    test "returns error for non-enumerable" do
      func = fn _ -> flunk("This shouldn't run") end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Errors.find_value(123, func)
      end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Errors.find_value({:ok, 123}, func)
      end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Errors.find_value(:ok, func)
      end
    end

    test "ok if first result is ok" do
      func = fn i -> if(i < 5, do: {:error, :below_five}, else: :ok) end

      assert Errors.find_value(1..10, func) == :ok
      assert Errors.find_value(5..10, func) == :ok
      assert Errors.find_value(8..10, func) == :ok

      assert Errors.find_value({:ok, 1..10}, func) == :ok
      assert Errors.find_value({:ok, 5..10}, func) == :ok
      assert Errors.find_value({:ok, 8..10}, func) == :ok
    end

    test "returns transformed result" do
      func = fn i ->
        if(i < 5, do: {:error, :below_five}, else: {:ok, i * 100})
      end

      assert Errors.find_value(1..10, func) == {:ok, 500}
      assert Errors.find_value(5..10, func) == {:ok, 500}
      assert Errors.find_value(8..10, func) == {:ok, 800}

      assert Errors.find_value({:ok, 1..10}, func) == {:ok, 500}
      assert Errors.find_value({:ok, 5..10}, func) == {:ok, 500}
      assert Errors.find_value({:ok, 8..10}, func) == {:ok, 800}
    end

    test "returns error with list when no successes" do
      func = fn i -> if(i < 5, do: {:error, :below_five}, else: :ok) end

      assert Errors.find_value(1..3, func) == {:error, [:below_five, :below_five, :below_five]}
    end

    test "exception raised" do
      func = fn _ -> raise "The test's error" end

      assert_raise RuntimeError, "The test's error", fn -> Errors.find_value(1..4, func) end
    end

    test "throw" do
      func = fn _ -> throw(:the_thrown_value) end

      assert catch_throw(Errors.find_value(1..4, func)) == :the_thrown_value
    end

    test "doesn't do anything when given an error" do
      func = fn _ -> flunk("This shouldn't run") end

      assert Errors.find_value({:error, :very_specific}, func) == {:error, :very_specific}
      assert Errors.find_value(:error, func) == :error
    end
  end
end
