defmodule Triage.OkErrorTest do
  use ExUnit.Case

  describe "ok?/1" do
    test "returns true for :ok" do
      assert Triage.ok?(:ok) == true
    end

    test "returns true for {:ok, _}" do
      assert Triage.ok?({:ok, :test}) == true
      assert Triage.ok?({:ok, 123}) == true
      assert Triage.ok?({:ok, "a string"}) == true
      assert Triage.ok?({:ok, %{key: :value}}) == true
    end

    test "returns true for {:ok, _, _}" do
      assert Triage.ok?({:ok, :test, :foo}) == true
      assert Triage.ok?({:ok, 123, "metadata"}) == true
      assert Triage.ok?({:ok, "value", %{context: :info}}) == true
    end

    test "returns true for {:ok, _, _, _}" do
      assert Triage.ok?({:ok, :test, :foo, :bar}) == true
      assert Triage.ok?({:ok, 1, 2, 3}) == true
    end

    test "returns false for :error" do
      assert Triage.ok?(:error) == false
    end

    test "returns false for {:error, _}" do
      assert Triage.ok?({:error, :test}) == false
      assert Triage.ok?({:error, 123}) == false
      assert Triage.ok?({:error, "a string"}) == false
      assert Triage.ok?({:error, %{key: :value}}) == false
    end

    test "returns false for {:error, _, _}" do
      assert Triage.ok?({:error, :test, :foo}) == false
      assert Triage.ok?({:error, 123, "metadata"}) == false
      assert Triage.ok?({:error, "reason", %{context: :info}}) == false
    end

    test "returns false for {:error, _, _, _}" do
      assert Triage.ok?({:error, :test, :foo, :bar}) == false
      assert Triage.ok?({:error, 1, 2, 3}) == false
    end

    test "raises ArgumentError for invalid values" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, ...} / :ok / {:error, ...} / :error, got: 123",
                   fn ->
                     Triage.ok?(123)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, ...} / :ok / {:error, ...} / :error, got: :ignore",
                   fn ->
                     Triage.ok?(:ignore)
                   end
    end
  end

  describe "error?/1" do
    test "returns true for :error" do
      assert Triage.error?(:error) == true
    end

    test "returns true for {:error, _}" do
      assert Triage.error?({:error, :test}) == true
      assert Triage.error?({:error, 123}) == true
      assert Triage.error?({:error, "a string"}) == true
      assert Triage.error?({:error, %{key: :value}}) == true
    end

    test "returns true for {:error, _, _}" do
      assert Triage.error?({:error, :test, :foo}) == true
      assert Triage.error?({:error, 123, "metadata"}) == true
      assert Triage.error?({:error, "reason", %{context: :info}}) == true
    end

    test "returns true for {:error, _, _, _}" do
      assert Triage.error?({:error, :test, :foo, :bar}) == true
      assert Triage.error?({:error, 1, 2, 3}) == true
    end

    test "returns false for :ok" do
      assert Triage.error?(:ok) == false
    end

    test "returns false for {:ok, _}" do
      assert Triage.error?({:ok, :test}) == false
      assert Triage.error?({:ok, 123}) == false
      assert Triage.error?({:ok, "a string"}) == false
      assert Triage.error?({:ok, %{key: :value}}) == false
    end

    test "returns false for {:ok, _, _}" do
      assert Triage.error?({:ok, :test, :foo}) == false
      assert Triage.error?({:ok, 123, "metadata"}) == false
      assert Triage.error?({:ok, "value", %{context: :info}}) == false
    end

    test "returns false for {:ok, _, _, _}" do
      assert Triage.error?({:ok, :test, :foo, :bar}) == false
      assert Triage.error?({:ok, 1, 2, 3}) == false
    end

    test "raises ArgumentError for invalid values" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, ...} / :ok / {:error, ...} / :error, got: 123",
                   fn ->
                     Triage.error?(123)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, ...} / :ok / {:error, ...} / :error, got: :ignore",
                   fn ->
                     Triage.error?(:ignore)
                   end
    end
  end
end
