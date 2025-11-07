defmodule Triage.ValidateTest do
  use ExUnit.Case

  alias Triage.Validate

  describe "strict" do
    test ":ok" do
      # no raise
      Validate.validate_result!(:ok, :strict)
    end

    test ":error" do
      # no raise
      Validate.validate_result!(:error, :strict)
    end

    test "{:ok, _}" do
      # no raise
      Validate.validate_result!({:ok, :test}, :strict)
      Validate.validate_result!({:ok, 123}, :strict)
      Validate.validate_result!({:ok, "a string"}, :strict)
    end

    test "{:error, _}" do
      # no raise
      Validate.validate_result!({:error, :test}, :strict)
      Validate.validate_result!({:error, 123}, :strict)
      Validate.validate_result!({:error, "a string"}, :strict)
    end

    test "{:ok, _, _}" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: {:ok, :test, :foo}",
                   fn ->
                     Validate.validate_result!({:ok, :test, :foo}, :strict)
                   end
    end

    test "{:error, _, _}" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: {:error, :test, :foo}",
                   fn ->
                     Validate.validate_result!({:error, :test, :foo}, :strict)
                   end
    end

    test "other values" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     Validate.validate_result!(123, :strict)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: :ignore",
                   fn ->
                     Validate.validate_result!(:ignore, :strict)
                   end
    end
  end

  describe "loose" do
    test ":ok" do
      # no raise
      Validate.validate_result!(:ok, :loose)
    end

    test ":error" do
      # no raise
      Validate.validate_result!(:error, :loose)
    end

    test "{:ok, _}" do
      # no raise
      Validate.validate_result!({:ok, :test}, :loose)
      Validate.validate_result!({:ok, 123}, :loose)
      Validate.validate_result!({:ok, "a string"}, :loose)
    end

    test "{:error, _}" do
      # no raise
      Validate.validate_result!({:error, :test}, :loose)
      Validate.validate_result!({:error, 123}, :loose)
      Validate.validate_result!({:error, "a string"}, :loose)
    end

    test "{:ok, _, _}" do
      # no raise
      Validate.validate_result!({:ok, :test, :foo}, :loose)
    end

    test "{:error, _, _}" do
      # no raise
      Validate.validate_result!({:error, :test, :foo}, :loose)
    end

    test "other values" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, ...} / :ok / {:error, ...} / :error, got: 123",
                   fn ->
                     Validate.validate_result!(123, :loose)
                   end

      assert_raise ArgumentError,
                   "Argument must be {:ok, ...} / :ok / {:error, ...} / :error, got: :ignore",
                   fn ->
                     Validate.validate_result!(:ignore, :loose)
                   end
    end
  end
end
