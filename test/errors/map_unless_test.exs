defmodule Triage.MapUnlessTest do
  use ExUnit.Case

  describe "map_unless/2" do
    test "returns error for non-enumerable" do
      func = fn _ -> flunk("This shouldn't run") end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Triage.map_unless(123, func)
      end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Triage.map_unless({:ok, 123}, func)
      end

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented/, fn ->
        Triage.map_unless(:ok, func)
      end
    end

    test "all ok 👍" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: {:ok, i * 100}) end

      # Maybe not 
      assert Triage.map_unless(1..4, func) == {:ok, [100, 200, 300, 400]}

      assert Triage.map_unless({:ok, 1..4}, func) == {:ok, [100, 200, 300, 400]}
    end

    test "uh oh error tuple! 🫣" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: {:ok, i * 100}) end

      # Maybe not 
      assert Triage.map_unless(1..10, func) == {:error, :is_five}

      assert Triage.map_unless({:ok, 1..10}, func) == {:error, :is_five}
    end

    test "uh oh error atom 🫣" do
      func = fn i -> if(i == 5, do: :error, else: {:ok, i * 100}) end

      # Maybe not 
      assert Triage.map_unless(1..10, func) == :error

      assert Triage.map_unless({:ok, 1..10}, func) == :error
    end

    test "exception raised" do
      func = fn _ -> raise "The test's error" end

      assert_raise RuntimeError, "The test's error", fn -> Triage.map_unless(1..4, func) end
    end

    test "throw" do
      func = fn _ -> throw(:the_thrown_value) end

      assert catch_throw(Triage.map_unless(1..4, func)) == :the_thrown_value
    end

    test "doesn't do anything when given an error" do
      func = fn _ -> flunk("This shouldn't run") end

      assert Triage.map_unless({:error, :very_specific}, func) ==
               {:error, :very_specific}

      assert Triage.map_unless(:error, func) == :error
    end
  end
end
