defmodule Triage.ThenTest do
  use ExUnit.Case

  describe "then!/1" do
    test "Returns term as success" do
      start = 123
      assert Triage.then!(fn -> start * 2 end) == {:ok, 246}
    end

    test "Returns :ok as :ok" do
      assert Triage.then!(fn -> :ok end) == :ok
    end

    test "Returns success with value as success" do
      start = 123
      assert Triage.then!(fn -> {:ok, start * 2} end) == {:ok, 246}
    end

    test "Returns :error as :error" do
      assert Triage.then!(fn -> :error end) == :error
    end

    test "Returns error with value as error" do
      assert Triage.then!(fn -> {:error, "Test error"} end) == {:error, "Test error"}
    end
  end

  describe "then!/2" do
    test "only allows result values for first argument" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 321",
                   fn ->
                     Triage.then!(321, fn _ -> 123 end)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: :eror",
                   fn ->
                     Triage.then!(:eror, fn _ -> 123 end)
                   end
    end

    test "passes value from {:ok, term} to function" do
      result = {:ok, 10}
      assert Triage.then!(result, fn x -> x * 2 end) == {:ok, 20}
    end

    test "passes nil to function when given :ok" do
      result = :ok
      assert Triage.then!(result, fn nil -> 42 end) == {:ok, 42}
    end

    test "returns :error without calling function" do
      result = :error
      assert Triage.then!(result, fn _ -> raise "Should not be called" end) == :error
    end

    test "returns {:error, term} without calling function" do
      result = {:error, "some error"}

      assert Triage.then!(result, fn _ -> raise "Should not be called" end) ==
               {:error, "some error"}
    end

    test "passes through :ok from function" do
      result = {:ok, 5}
      assert Triage.then!(result, fn 5 -> :ok end) == :ok
    end

    test "passes through :error from function" do
      result = {:ok, 5}
      assert Triage.then!(result, fn 5 -> :error end) == :error
    end

    test "passes through {:error, _} from function" do
      result = {:ok, 5}
      assert Triage.then!(result, fn _ -> {:error, "failed"} end) == {:error, "failed"}
    end

    test "chains multiple then! calls" do
      result =
        {:ok, 10}
        |> Triage.then!(fn x -> x + 5 end)
        |> Triage.then!(fn x -> x * 2 end)
        |> Triage.then!(fn x -> x - 10 end)

      assert result == {:ok, 20}
    end

    test "stops chain on error" do
      result =
        {:ok, 10}
        |> Triage.then!(fn x -> x + 5 end)
        |> Triage.then!(fn 15 -> {:error, "oops"} end)
        |> Triage.then!(fn _ -> raise "Should not be called" end)

      assert result == {:error, "oops"}
    end

    test "does not catch exceptions" do
      assert_raise RuntimeError, "The raised error", fn ->
        {:ok, 10}
        |> Triage.then!(fn x -> x + 5 end)
        |> Triage.then!(fn _ -> raise "The raised error" end)
        |> Triage.then!(fn _ -> raise "Should not be called" end)
      end
    end

    test "handles :ok in chain" do
      result =
        {:ok, 10}
        |> Triage.then!(fn _ -> :ok end)
        |> Triage.then!(fn nil -> 42 end)

      assert result == {:ok, 42}
    end
  end

  describe "then/1" do
    test "Returns term as success" do
      start = 123
      assert Triage.then(fn -> start * 2 end) == {:ok, 246}
    end

    test "Returns :ok as :ok" do
      assert Triage.then(fn -> :ok end) == :ok
    end

    test "Returns success with value as success" do
      start = 123
      assert Triage.then(fn -> {:ok, start * 2} end) == {:ok, 246}
    end

    test "Returns :error as :error" do
      assert Triage.then(fn -> :error end) == :error
    end

    test "Returns error with value as error" do
      assert Triage.then(fn -> {:error, "Test error"} end) == {:error, "Test error"}
    end

    test "An exception is raised" do
      {:error, %Triage.WrappedError{} = wrapped_error} =
        Triage.then(fn -> raise "boom" end)

      assert wrapped_error.message =~
               ~r<\*\* \(RuntimeError\) boom\n    \[CONTEXT\] test/triage/then_test\.exs:\d+: Triage\.ThenTest\.-test then/1 An exception is raised/1-fun-0-/1>

      assert wrapped_error.result == %RuntimeError{message: "boom"}
    end
  end

  describe "then/2" do
    test "behaves like then!/2 for successful operations" do
      result = {:ok, 10}
      assert Triage.then(result, fn x -> x * 2 end) == {:ok, 20}
    end

    test "passes nil to function when given :ok" do
      result = :ok
      assert Triage.then(result, fn nil -> 42 end) == {:ok, 42}
    end

    test "returns :error without calling function" do
      result = :error
      assert Triage.then(result, fn _ -> raise "Should not be called" end) == :error
    end

    test "returns {:error, term} without calling function" do
      result = {:error, "some error"}

      assert Triage.then(result, fn _ -> raise "Should not be called" end) ==
               {:error, "some error"}
    end

    test "catches exceptions and wraps them in WrappedError" do
      result = {:ok, 10}

      {:error, %Triage.WrappedError{} = wrapped_error} =
        Triage.then(result, fn _ -> raise "boom" end)

      assert wrapped_error.result == %RuntimeError{message: "boom"}
    end

    test "chains multiple then calls" do
      result =
        {:ok, 10}
        |> Triage.then(fn x -> x + 5 end)
        |> Triage.then(fn x -> x * 2 end)
        |> Triage.then(fn x -> x - 10 end)

      assert result == {:ok, 20}
    end

    test "stops chain on error" do
      result =
        {:ok, 10}
        |> Triage.then(fn x -> x + 5 end)
        |> Triage.then(fn 15 -> {:error, "oops"} end)
        |> Triage.then(fn _ -> raise "Should not be called" end)

      assert result == {:error, "oops"}
    end

    test "catches exception and stops chain" do
      result =
        {:ok, 10}
        |> Triage.then(fn x -> x + 5 end)
        |> Triage.then(fn _ -> raise "boom" end)
        |> Triage.then(fn _ -> raise "Should not be called" end)

      assert {:error, %Triage.WrappedError{result: %RuntimeError{message: "boom"}}} =
               result
    end

    test "catches ArgumentError" do
      result = Triage.then({:ok, "test"}, fn _ -> raise ArgumentError, "invalid argument" end)

      assert {:error, %Triage.WrappedError{result: %ArgumentError{message: "invalid argument"}}} =
               result
    end

    test "catches custom exceptions" do
      defmodule CustomError do
        defexception message: "custom error"
      end

      assert {:error, %Triage.WrappedError{result: reason}} =
               Triage.then({:ok, 5}, fn _ -> raise CustomError end)

      assert reason.__struct__ == CustomError
      assert reason.message == "custom error"
    end
  end
end
