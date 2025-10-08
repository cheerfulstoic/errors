defmodule Errors.LogTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  require Logger

  describe ".log with :error mode" do
    test "logs and passes through :error atom" do
      log =
        capture_log([level: :error], fn ->
          result = :error |> Errors.log(:error)
          assert result == :error
        end)

      assert log =~ "[RESULT] :error"
    end

    test "logs and passes through {:error, binary}" do
      log =
        capture_log([level: :error], fn ->
          result = {:error, "something went wrong"} |> Errors.log(:error)
          assert result == {:error, "something went wrong"}
        end)

      assert log =~ "[RESULT] {:error, \"something went wrong\"}"
    end

    test "logs and passes through {:error, atom}" do
      log =
        capture_log([level: :error], fn ->
          result = {:error, :timeout} |> Errors.log(:error)
          assert result == {:error, :timeout}
        end)

      assert log =~ "[RESULT] {:error, :timeout}"
    end

    test "logs and passes through {:error, exception}" do
      exception = %RuntimeError{message: "an example error message"}

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log(:error)
          assert result == {:error, exception}
        end)

      assert log =~ "[RESULT] {:error, %RuntimeError{...}} (message: an example error message)"
    end

    test "logs and passes through {:error, %Errors.WrappedError{}}" do
      exception = Errors.WrappedError.new(:failed, "fooing the bar")

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log(:error)
          assert result == {:error, exception}
        end)

      assert log =~ "[RESULT] WRAPPED ERROR (fooing the bar) :failed"

      # Nested
      exception =
        Errors.WrappedError.new(
          Errors.WrappedError.new(
            %RuntimeError{message: "an example error message"},
            "lower down"
          ),
          "higher up"
        )

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log(:error)
          assert result == {:error, exception}
        end)

      assert log =~
               "[RESULT] WRAPPED ERROR (higher up => lower down) RuntimeError: an example error message"
    end

    test "does not log :ok atom" do
      log =
        capture_log([level: :error], fn ->
          result = :ok |> Errors.log(:error)
          assert result == :ok
        end)

      assert log == ""
    end

    test "does not log {:ok, value}" do
      log =
        capture_log([level: :error], fn ->
          result = {:ok, "success"} |> Errors.log(:error)
          assert result == {:ok, "success"}
        end)

      assert log == ""
    end

    test "passes through other values without logging" do
      log =
        capture_log([level: :error], fn ->
          result = "random value" |> Errors.log(:error)
          assert result == "random value"
        end)

      assert log == ""
    end
  end

  describe ".log with :all mode" do
    test "logs :error atom" do
      log =
        capture_log([level: :info], fn ->
          result = :error |> Errors.log(:all)
          assert result == :error
        end)

      assert log =~ "[RESULT] :error"
    end

    test "logs {:error, binary}" do
      log =
        capture_log([level: :info], fn ->
          result = {:error, "something went wrong"} |> Errors.log(:all)
          assert result == {:error, "something went wrong"}
        end)

      assert log =~ "[RESULT] {:error, \"something went wrong\"}"
    end

    test "logs :ok atom" do
      log =
        capture_log([level: :info], fn ->
          result = :ok |> Errors.log(:all)
          assert result == :ok
        end)

      assert log =~ "[RESULT] :ok"
    end

    test "logs {:ok, value}" do
      log =
        capture_log([level: :info], fn ->
          result = {:ok, "success"} |> Errors.log(:all)
          assert result == {:ok, "success"}
        end)

      assert log =~ "[RESULT] {:ok, \"success\"}"
    end

    test "passes through other values without logging" do
      log =
        capture_log([level: :info], fn ->
          result = "random value" |> Errors.log(:all)
          assert result == "random value"
        end)

      assert log == ""
    end
  end

  describe "Errors.log/2 log levels" do
    test "errors results log at level: :error" do
      # {:error, _}
      log =
        capture_log([level: :error], fn ->
          {:error, "test"} |> Errors.log(:error)
        end)

      assert log =~ "[RESULT] {:error, \"test\"}"

      # Should not appear at warning level
      log =
        capture_log([level: :critical], fn ->
          {:error, "test"} |> Errors.log(:error)
        end)

      refute log =~ "RESULT"

      # :error
      log =
        capture_log([level: :error], fn ->
          :error |> Errors.log(:error)
        end)

      assert log =~ "[RESULT] :error"

      # Should not appear at warning level
      log =
        capture_log([level: :critical], fn ->
          :error |> Errors.log(:error)
        end)

      refute log =~ "RESULT"
    end

    test "ok results log at level: :info" do
      # {:ok, _}
      log =
        capture_log([level: :info], fn ->
          {:ok, 123} |> Errors.log(:all)
        end)

      assert log =~ "[RESULT] {:ok, 123}"

      # Should not appear at warning level
      log =
        capture_log([level: :notice], fn ->
          {:ok, 123} |> Errors.log(:all)
        end)

      refute log =~ "RESULT"

      # :ok
      log =
        capture_log([level: :info], fn ->
          :ok |> Errors.log(:all)
        end)

      assert log =~ "[RESULT] :ok"

      # Should not appear at warning level
      log =
        capture_log([level: :notice], fn ->
          :ok |> Errors.log(:all)
        end)

      refute log =~ "RESULT"
    end
  end
end
