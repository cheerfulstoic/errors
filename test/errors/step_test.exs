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

  describe "step!/2" do
    test "only allows result values for first argument" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 321",
                   fn ->
                     Errors.step!(321, fn _ -> 123 end)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: :eror",
                   fn ->
                     Errors.step!(:eror, fn _ -> 123 end)
                   end
    end

    test "passes value from {:ok, term} to function" do
      result = {:ok, 10}
      assert Errors.step!(result, fn x -> x * 2 end) == {:ok, 20}
    end

    test "passes nil to function when given :ok" do
      result = :ok
      assert Errors.step!(result, fn nil -> 42 end) == {:ok, 42}
    end

    test "returns :error without calling function" do
      result = :error
      assert Errors.step!(result, fn _ -> raise "Should not be called" end) == :error
    end

    test "returns {:error, term} without calling function" do
      result = {:error, "some error"}

      assert Errors.step!(result, fn _ -> raise "Should not be called" end) ==
               {:error, "some error"}
    end

    test "passes through :ok from function" do
      result = {:ok, 5}
      assert Errors.step!(result, fn 5 -> :ok end) == :ok
    end

    test "passes through :error from function" do
      result = {:ok, 5}
      assert Errors.step!(result, fn 5 -> :error end) == :error
    end

    test "passes through {:error, _} from function" do
      result = {:ok, 5}
      assert Errors.step!(result, fn _ -> {:error, "failed"} end) == {:error, "failed"}
    end

    test "chains multiple step! calls" do
      result =
        {:ok, 10}
        |> Errors.step!(fn x -> x + 5 end)
        |> Errors.step!(fn x -> x * 2 end)
        |> Errors.step!(fn x -> x - 10 end)

      assert result == {:ok, 20}
    end

    test "stops chain on error" do
      result =
        {:ok, 10}
        |> Errors.step!(fn x -> x + 5 end)
        |> Errors.step!(fn 15 -> {:error, "oops"} end)
        |> Errors.step!(fn _ -> raise "Should not be called" end)

      assert result == {:error, "oops"}
    end

    test "does not catch exceptions" do
      assert_raise RuntimeError, "The raised error", fn ->
        {:ok, 10}
        |> Errors.step!(fn x -> x + 5 end)
        |> Errors.step!(fn _ -> raise "The raised error" end)
        |> Errors.step!(fn _ -> {:error, "oops"} end)
      end
    end

    test "handles :ok in chain" do
      result =
        {:ok, 10}
        |> Errors.step!(fn _ -> :ok end)
        |> Errors.step!(fn nil -> 42 end)

      assert result == {:ok, 42}
    end
  end
end
