defmodule Errors.LogTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  require Logger

  setup do
    Application.delete_env(:errors, :app)

    :ok
  end

  describe ".log with :error mode" do
    test "argument can only be a result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     123 |> Errors.log(:errors)
                   end
    end

    test "logs and passes through :error atom" do
      log =
        capture_log([level: :error], fn ->
          result = :error |> Errors.log(:errors)
          assert result == :error
        end)

      assert log =~ ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) :error>
    end

    test "logs and passes through {:error, binary}" do
      log =
        capture_log([level: :error], fn ->
          result = {:error, "something went wrong"} |> Errors.log(:errors)
          assert result == {:error, "something went wrong"}
        end)

      assert log =~
               ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) {:error, \"something went wrong\"}>
    end

    test "logs and passes through {:error, atom}" do
      log =
        capture_log([level: :error], fn ->
          result = {:error, :timeout} |> Errors.log(:errors)
          assert result == {:error, :timeout}
        end)

      assert log =~ ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) {:error, :timeout}>
    end

    test "logs and passes through {:error, exception}" do
      exception = %RuntimeError{message: "an example error message"}

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log(:errors)
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) {:error, %RuntimeError{\.\.\.}} \(message: an example error message\)>
    end

    test "logs and passes through {:error, %Errors.WrappedError{}}" do
      exception = Errors.WrappedError.new({:error, :failed}, "fooing the bar")

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log(:errors)
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) \[CONTEXT: fooing the bar\] :failed>

      # Nested
      exception =
        Errors.WrappedError.new(
          {:error,
           Errors.WrappedError.new(
             {:error, %RuntimeError{message: "an example error message"}},
             "lower down"
           )},
          "higher up"
        )

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log(:errors)
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) \[CONTEXT: higher up =\> lower down\] RuntimeError: an example error message>
    end

    test "does not log :ok atom" do
      log =
        capture_log([level: :error], fn ->
          result = :ok |> Errors.log(:errors)
          assert result == :ok
        end)

      assert log == ""
    end

    test "does not log {:ok, value}" do
      log =
        capture_log([level: :error], fn ->
          result = {:ok, "success"} |> Errors.log(:errors)
          assert result == {:ok, "success"}
        end)

      assert log == ""
    end
  end

  describe ".log with :all mode" do
    test "argument can only be a result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     123 |> Errors.log(:all)
                   end
    end

    test "logs :error atom" do
      log =
        capture_log([level: :info], fn ->
          result = :error |> Errors.log(:all)
          assert result == :error
        end)

      assert log =~ ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) :error>
    end

    test "logs {:error, binary}" do
      log =
        capture_log([level: :info], fn ->
          result = {:error, "something went wrong"} |> Errors.log(:all)
          assert result == {:error, "something went wrong"}
        end)

      assert log =~
               ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) {:error, "something went wrong"}>
    end

    test "logs :ok atom" do
      log =
        capture_log([level: :info], fn ->
          result = :ok |> Errors.log(:all)
          assert result == :ok
        end)

      assert log =~ ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) :ok>
    end

    test "logs {:ok, value}" do
      log =
        capture_log([level: :info], fn ->
          result = {:ok, "success"} |> Errors.log(:all)
          assert result == {:ok, "success"}
        end)

      assert log =~ ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) {:ok, \"success\"}>
    end
  end

  describe "Errors.log/2 log levels" do
    # :error results
    test "{:error, _} logs at level: :error - shows app line if app configured" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :error], fn ->
          {:error, "test"} |> Errors.TestHelper.run_log(:errors)
        end)

      assert log =~ ~r<\[RESULT\] \(lib/errors/test_helper\.ex:\d+\) {:error, "test"}>

      # Should not appear at warning level
      log =
        capture_log([level: :critical], fn ->
          {:error, "test"} |> Errors.TestHelper.run_log(:errors)
        end)

      refute log =~ ~r<RESULT>
    end

    test "{:error, _} logs at level: :error - shows best default line if app not configured " do
      log =
        capture_log([level: :error], fn ->
          {:error, "test"} |> Errors.log(:errors)
        end)

      # With no app configured, it defaults to the first level up
      assert log =~ ~r<\[RESULT\] \(lib/ex_unit/capture_log\.ex:\d+\) {:error, "test"}>
    end

    test ":error logs at level: :error" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :error], fn ->
          :error |> Errors.TestHelper.run_log(:errors)
        end)

      assert log =~ ~r<\[RESULT\] \(lib/errors/test_helper\.ex:\d+\) :error>

      # Should not appear at warning level
      log =
        capture_log([level: :critical], fn ->
          :error |> Errors.TestHelper.run_log(:errors)
        end)

      refute log =~ "RESULT"
    end

    test "app configured, but :error result occurs where stacktrace does not have app" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :error], fn ->
          :error |> Errors.log(:errors)
        end)

      assert log =~ ~r<\[RESULT\] \(lib/ex_unit/capture_log.ex:\d+\) :error>
    end

    # TODO: Show that :ok results don't log when logging :errors
    # :ok results
    test "{:ok, _} logs at level: :ok - shows app line if app configured" do
      Application.put_env(:errors, :app, :all)

      log =
        capture_log([level: :info], fn ->
          {:ok, "test"} |> Errors.TestHelper.run_log(:all)
        end)

      assert log =~ ~r<\[RESULT\] \(lib/errors/test_helper\.ex:\d+\) {:ok, "test"}>

      # Should not appear at warning level
      log =
        capture_log([level: :notice], fn ->
          {:ok, "test"} |> Errors.TestHelper.run_log(:all)
        end)

      refute log =~ ~r<RESULT>
    end

    test "{:ok, _} logs at level: :error - shows best default line if app not configured " do
      log =
        capture_log([level: :info], fn ->
          {:ok, "test"} |> Errors.log(:all)
        end)

      # With no app configured, it defaults to the first level up
      assert log =~ ~r<\[RESULT\] \(lib/ex_unit/capture_log\.ex:\d+\) {:ok, "test"}>
    end

    test ":ok logs at level: :error" do
      Application.put_env(:errors, :app, :all)

      log =
        capture_log([level: :info], fn ->
          :ok |> Errors.TestHelper.run_log(:all)
        end)

      assert log =~ ~r<\[RESULT\] \(lib/errors/test_helper\.ex:\d+\) :ok>

      # Should not appear at warning level
      log =
        capture_log([level: :notice], fn ->
          :ok |> Errors.TestHelper.run_log(:all)
        end)

      refute log =~ "RESULT"
    end

    test "app configured, but :ok result occurs where stacktrace does not have app" do
      Application.put_env(:errors, :app, :all)

      log =
        capture_log([level: :info], fn ->
          :ok |> Errors.log(:all)
        end)

      assert log =~ ~r<\[RESULT\] \(lib/ex_unit/capture_log.ex:\d+\) :ok>
    end

    test "no logs at any level if :ok result and mode is :errors" do
      log =
        capture_log([level: :debug], fn ->
          :ok |> Errors.log(:errors)
        end)

      refute log =~ "RESULT"

      log =
        capture_log([level: :debug], fn ->
          {:ok, 123} |> Errors.log(:errors)
        end)

      refute log =~ "RESULT"
    end
  end
end
