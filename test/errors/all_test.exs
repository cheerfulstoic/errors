defmodule Errors.AllTest do
  use ExUnit.Case

  describe "all/2" do
    test "all oks" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: :ok) end

      assert Errors.all(1..4, func) == :ok
      assert Errors.all(6..9, func) == :ok

      assert Errors.all({:ok, 1..4}, func) == :ok
      assert Errors.all({:ok, 6..9}, func) == :ok
    end

    # ok tuples returned from the callback may not be a good fit for this function
    # but probably good to support it...
    test "callback ok tuples aren't used" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: {:ok, i * 2}) end

      assert Errors.all(1..4, func) == :ok
      assert Errors.all(6..9, func) == :ok

      assert Errors.all({:ok, 1..4}, func) == :ok
      assert Errors.all({:ok, 6..9}, func) == :ok
    end

    test "return first error" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: :ok) end

      assert Errors.all(5..7, func) == {:error, :is_five}
      assert Errors.all(3..7, func) == {:error, :is_five}

      assert Errors.all({:ok, 5..7}, func) == {:error, :is_five}
      assert Errors.all({:ok, 3..7}, func) == {:error, :is_five}

      func = fn i -> if(i == 5, do: :error, else: :ok) end

      assert Errors.all(5..7, func) == :error
      assert Errors.all(3..7, func) == :error

      assert Errors.all({:ok, 5..7}, func) == :error
      assert Errors.all({:ok, 3..7}, func) == :error
    end

    test "callback returns non-result" do
      func = fn i -> if(i == 5, do: {:error, :is_five}, else: 123) end

      assert_raise ArgumentError, ~r/Callback return must be /, fn ->
        Errors.all(1..4, func)
      end

      assert_raise ArgumentError, ~r/Callback return must be /, fn ->
        Errors.all({:ok, 1..4}, func)
      end
    end

    test "exception raised" do
      func = fn _ -> raise "The test's error" end

      assert_raise RuntimeError, "The test's error", fn -> Errors.all(1..4, func) end
    end

    test "throw" do
      func = fn _ -> throw(:the_thrown_value) end

      assert catch_throw(Errors.all(1..4, func)) == :the_thrown_value
    end

    test "doesn't do anything when given an error" do
      func = fn _ -> flunk("This shouldn't run") end

      assert Errors.all({:error, :very_specific}, func) == {:error, :very_specific}
      assert Errors.all(:error, func) == :error
    end
  end
end
