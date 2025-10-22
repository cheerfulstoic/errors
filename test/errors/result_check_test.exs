defmodule Errors.ResultCheckTest do
  use ExUnit.Case

  describe "ok?/1" do
    test "Given :ok" do
      assert Errors.ok?(:ok)
    end

    test "Given {:ok, term()}" do
      assert Errors.ok?({:ok, 42})
      assert Errors.ok?({:ok, "hello"})
      assert Errors.ok?({:ok, %{key: "value"}})
    end

    test "Given :error" do
      refute Errors.ok?(:error)
    end

    test "Given {:error, term()}" do
      refute Errors.ok?({:error, :not_found})
      refute Errors.ok?({:error, "something went wrong"})
    end

    test "Given a non-result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     Errors.ok?(123)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: \"invalid\"",
                   fn ->
                     Errors.ok?("invalid")
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: {:bad, :tuple}",
                   fn ->
                     Errors.ok?({:bad, :tuple})
                   end
    end
  end

  describe "error?/1" do
    test "Given :error" do
      assert Errors.error?(:error)
    end

    test "Given {:error, term()}" do
      assert Errors.error?({:error, :not_found})
      assert Errors.error?({:error, "something went wrong"})
      assert Errors.error?({:error, %{reason: "failed"}})
    end

    test "Given :ok" do
      refute Errors.error?(:ok)
    end

    test "Given {:ok, term()}" do
      refute Errors.error?({:ok, 42})
      refute Errors.error?({:ok, "hello"})
    end

    test "Given a non-result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     Errors.error?(123)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: \"invalid\"",
                   fn ->
                     Errors.error?("invalid")
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: {:bad, :tuple}",
                   fn ->
                     Errors.error?({:bad, :tuple})
                   end
    end
  end
end
