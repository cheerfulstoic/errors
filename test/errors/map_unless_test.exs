defmodule Errors.MapUnlessTest do
  use ExUnit.Case

  describe "map_unless/2" do
    test "returns error for non-enumerable" do
      func = fn i -> flunk("This shouldn't run") end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Errors.map_unless(123, func)
      end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Errors.map_unless({:ok, 123}, func)
      end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Errors.map_unless(:ok, func)
      end
    end

    test "all ok 👍" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: {:ok, i * 100}) end

      # Maybe not 
      assert Errors.map_unless(1..4, func) == {:ok, [100, 200, 300, 400]}

      assert Errors.map_unless({:ok, 1..4}, func) == {:ok, [100, 200, 300, 400]}
    end

    test "uh oh error tuple! 🫣" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: {:ok, i * 100}) end

      # Maybe not 
      assert Errors.map_unless(1..10, func) == {:error, :is_five}

      assert Errors.map_unless({:ok, 1..10}, func) == {:error, :is_five}
    end

    test "uh oh error atom 🫣" do
      func = fn i -> if(i == 5, do: :error, else: {:ok, i * 100}) end

      # Maybe not 
      assert Errors.map_unless(1..10, func) == :error

      assert Errors.map_unless({:ok, 1..10}, func) == :error
    end

    test "doesn't do anything when given an error" do
      func = fn i -> flunk("This shouldn't run") end

      Errors.map_unless({:error, :very_specific}, func) ==
        {:error, :very_specific}

      Errors.map_unless(:error, func) == :error
    end
  end
end
