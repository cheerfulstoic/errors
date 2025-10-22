defmodule Errors.MapTest do
  use ExUnit.Case

  describe "map!/2" do
    test "Given :ok" do
      assert_raise ArgumentError, "Cannot pass :ok to map!/2", fn ->
        Errors.map!(:ok, fn i -> {:ok, i * 2} end)
      end
    end

    test "Given {:error, term()}" do
      assert Errors.map!(:error, fn i -> {:ok, i * 2} end) == :error
    end

    test "Given :error" do
      assert Errors.map!({:error, :not_found}, fn i -> {:ok, i * 2} end) == {:error, :not_found}
    end

    test "Given a non-result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / {:error, _} / :error, got: 123",
                   fn ->
                     Errors.map!(123, fn i -> {:ok, i * 2} end)
                   end
    end

    test "happy path" do
      result =
        {:ok, [1, 2, 3]}
        |> Errors.map!(fn i ->
          {:ok, i * 2}
        end)

      assert result == [{:ok, 2}, {:ok, 4}, {:ok, 6}]
    end

    test "failures" do
      result =
        {:ok, [1, 2, 3, 4]}
        |> Errors.map!(fn i ->
          if rem(i, 2) == 0 do
            {:error, :even_number}
          else
            {:ok, i * 2}
          end
        end)

      assert result == [{:ok, 2}, {:error, :even_number}, {:ok, 6}, {:error, :even_number}]
    end

    test "exception" do
      assert_raise RuntimeError, "Oh no! Even number!! Was 2", fn ->
        {:ok, [1, 2, 3, 4]}
        |> Errors.map!(fn i ->
          if rem(i, 2) == 0 do
            raise "Oh no! Even number!! Was #{i}"
          else
            {:ok, i * 2}
          end
        end)
      end
    end
  end

  describe "map/2" do
    test "Given :ok" do
      assert_raise ArgumentError, "Cannot pass :ok to map/2", fn ->
        Errors.map(:ok, fn i -> {:ok, i * 2} end)
      end
    end

    test "Given {:error, term()}" do
      assert Errors.map(:error, fn i -> {:ok, i * 2} end) == :error
    end

    test "Given :error" do
      assert Errors.map({:error, :not_found}, fn i -> {:ok, i * 2} end) == {:error, :not_found}
    end

    test "Given a non-result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / {:error, _} / :error, got: 123",
                   fn ->
                     Errors.map(123, fn i -> {:ok, i * 2} end)
                   end
    end

    test "happy path" do
      result =
        {:ok, [1, 2, 3]}
        |> Errors.map(fn i ->
          {:ok, i * 2}
        end)

      assert result == [{:ok, 2}, {:ok, 4}, {:ok, 6}]
    end

    test "failures" do
      result =
        {:ok, [1, 2, 3, 4]}
        |> Errors.map(fn i ->
          if rem(i, 2) == 0 do
            {:error, :even_number}
          else
            {:ok, i * 2}
          end
        end)

      assert result == [{:ok, 2}, {:error, :even_number}, {:ok, 6}, {:error, :even_number}]
    end

    test "exception" do
      func = fn i ->
        if rem(i, 2) == 0 do
          raise "Oh no! Even number!! Was #{i}"
        else
          {:ok, i * 2}
        end
      end

      result =
        {:ok, [1, 2, 3, 4]}
        |> Errors.map(func)

      assert [
               {:ok, 2},
               {:error, %Errors.WrappedError{} = error1},
               {:ok, 6},
               {:error, %Errors.WrappedError{} = error2}
             ] = result

      assert error1.message ==
               "** (RuntimeError) Oh no! Even number!! Was 2\n    [CONTEXT] test/errors/map_test.exs:115: Errors.MapTest.-test map/2 exception/1-fun-0-/1"

      assert %RuntimeError{message: "Oh no! Even number!! Was 2"} = error1.result
      assert %RuntimeError{message: "Oh no! Even number!! Was 2"} = error1.reason
      assert error1.context == func

      assert {Errors.MapTest, :"-test map/2 exception/1-fun-0-", 1,
              [file: ~c"test/errors/map_test.exs", line: _, error_info: %{module: Exception}]} =
               List.first(error1.stacktrace)

      assert error2.message ==
               "** (RuntimeError) Oh no! Even number!! Was 4\n    [CONTEXT] test/errors/map_test.exs:115: Errors.MapTest.-test map/2 exception/1-fun-0-/1"

      assert %RuntimeError{message: "Oh no! Even number!! Was 4"} = error2.result
      assert %RuntimeError{message: "Oh no! Even number!! Was 4"} = error2.reason
      assert error2.context == func

      assert {Errors.MapTest, :"-test map/2 exception/1-fun-0-", 1,
              [file: ~c"test/errors/map_test.exs", line: _, error_info: %{module: Exception}]} =
               List.first(error2.stacktrace)
    end
  end
end
