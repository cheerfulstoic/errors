defmodule Errors.LogTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  require Logger

  defmodule CustomStruct do
    defstruct [:id, :foo, :user_id, :bar]
  end

  defmodule OtherCustomStruct do
    defstruct [:id, :name, :something, :fooID]
  end

  defmodule CustomError do
    defexception [:message]
  end

  defmodule User do
    use Ecto.Schema

    embedded_schema do
      field(:name, :string)
    end
  end

  setup do
    Application.delete_env(:errors, :app)
    Application.delete_env(:errors, :log_adapter)

    on_exit(fn ->
      Application.delete_env(:errors, :app)
      Application.delete_env(:errors, :log_adapter)
    end)

    :ok
  end

  describe "validation" do
    test "mode must be :errors or :all" do
      assert_raise ArgumentError,
                   "mode must be either :errors or :all (got: :something_else)",
                   fn ->
                     Errors.log(:ok, :something_else)
                   end
    end
  end

  describe ".log with :error mode" do
    test "argument can only be a result" do
      assert_raise ArgumentError,
                   "Argument must be {:ok, _} / :ok / {:error, _} / :error, got: 123",
                   fn ->
                     123 |> Errors.log()
                   end
    end

    test "logs and passes through :error atom" do
      log =
        capture_log([level: :error], fn ->
          result = :error |> Errors.log()
          assert result == :error
        end)

      assert log =~ ~r<\[RESULT\] test/errors/log_test\.exs:\d+: :error>
    end

    test "logs and passes through {:error, binary}" do
      log =
        capture_log([level: :error], fn ->
          result = {:error, "something went wrong"} |> Errors.log()
          assert result == {:error, "something went wrong"}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, \"something went wrong\"}>
    end

    test "logs and passes through {:error, atom}" do
      log =
        capture_log([level: :error], fn ->
          result = {:error, :timeout} |> Errors.log()
          assert result == {:error, :timeout}
        end)

      assert log =~ ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, :timeout}>
    end

    test "logs and passes through {:error, exception}" do
      exception = %RuntimeError{message: "an example error message"}

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log()
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, #RuntimeError\<\.\.\.\>} \(message: an example error message\)>
    end

    test "logs and passes through {:error, %Errors.WrappedError{}}" do
      exception =
        Errors.WrappedError.new({:error, :failed}, "fooing the bar", [
          # Made up stacktrace line using a real module so we get a realistic-ish line/number
          {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ])

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log()
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, :failed}
    \[CONTEXT\] lib/errors/test_helper.ex:10: fooing the bar>
    end

    test "WrappedError with nil context" do
      exception =
        Errors.WrappedError.new(
          {:error, :failed},
          nil,
          [
            # Made up stacktrace line using a real module so we get a realistic-ish line/number
            {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
          ],
          %{foo: 123, bar: "baz"}
        )

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log()
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, :failed}
    \[CONTEXT\] lib/errors/test_helper.ex:10: %{bar: \"baz\", foo: 123}>
    end

    test "WrappedError with raised exception" do
      func = fn i -> i * 2 end

      exception =
        Errors.WrappedError.new_raised(
          %RuntimeError{message: "an example error message"},
          # Raised exceptions get a func context when wrapped 
          func,
          [
            # Made up stacktrace line using a real module so we get a realistic-ish line/number
            {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
          ]
        )

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log()
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: \*\* \(RuntimeError\) an example error message
    \[CONTEXT\] lib/errors/test_helper.ex:10: Errors\.LogTest\.-test>
    end

    test "Nested WrappedError" do
      # Nested
      exception =
        Errors.WrappedError.new(
          {:error,
           Errors.WrappedError.new(
             {:error, %RuntimeError{message: "an example error message"}},
             "lower down",
             [
               {Errors.TestHelper, :made_up_function, 0,
                [file: ~c"lib/errors/test_helper.ex", line: 18]}
             ],
             %{a: 123, b: "baz"}
           )},
          "higher up",
          [
            {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
          ],
          %{b: "biz", something: %{whatever: :hello}, c: :foo}
        )

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log()
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<a=123 b=baz c=foo \[error\] \[RESULT\] test/errors/log_test\.exs:\d+: {:error, #RuntimeError\<\.\.\.\>} \(message: an example error message\)
    \[CONTEXT\] lib/errors/test_helper.ex:10: higher up %{b: "biz", c: :foo, something: %{whatever: :hello}}
    \[CONTEXT\] lib/errors/test_helper.ex:18: lower down %{a: 123, b: "baz"}>
    end

    test "does not log :ok atom" do
      log =
        capture_log([level: :error], fn ->
          result = :ok |> Errors.log()
          assert result == :ok
        end)

      assert log == ""
    end

    test "does not log {:ok, value}" do
      log =
        capture_log([level: :error], fn ->
          result = {:ok, "success"} |> Errors.log()
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

      assert log =~ ~r<\[RESULT\] test/errors/log_test\.exs:\d+: :error>
    end

    test "logs {:error, binary}" do
      log =
        capture_log([level: :info], fn ->
          result = {:error, "something went wrong"} |> Errors.log(:all)
          assert result == {:error, "something went wrong"}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, "something went wrong"}>
    end

    test "logs Ecto.Changeset error" do
      log =
        capture_log([level: :info], fn ->
          result =
            %User{}
            |> Ecto.Changeset.cast(%{name: 1}, [:name])
            |> Ecto.Changeset.apply_action(:insert)
            |> Errors.log(:all)

          assert {:error,
                  %Ecto.Changeset{
                    valid?: false,
                    data: %Errors.LogTest.User{},
                    errors: [name: {"is invalid", [type: :string, validation: :cast]}]
                  }} = result
        end)

      # Uses Ecto's `inspect` implementation
      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, #Ecto\.Changeset\<action: :insert, changes: %{}, data: #Errors\.LogTest\.User\<id: nil, name: nil, \.\.\.\>, errors: \[name: {"is invalid", \[type: :string, validation: :cast\]}\], params: %{"name" =\> 1}, valid\?: false, \.\.\.\>}>
    end

    test "logs custom struct" do
      log =
        capture_log([level: :info], fn ->
          {:error, %CustomStruct{id: 123, foo: "thing", user_id: 456, bar: "other"}}
          |> Errors.log(:all)
        end)

      # Uses Ecto's `inspect` implementation
      assert log =~
               ~r<\[RESULT\] lib\/ex_unit\/capture_log\.ex:\d+: {:error, #Errors\.LogTest\.CustomStruct\<id: 123, user_id: 456, \.\.\.\>}>
    end

    test "logs nested custom structs in error tuples" do
      log =
        capture_log([level: :error], fn ->
          {:error,
           %CustomStruct{
             id: 123,
             foo: "thing",
             user_id: 456,
             bar: %OtherCustomStruct{id: 789, name: "Cool", something: "hi", fooID: 000}
           }}
          |> Errors.log(:all)
        end)

      # Uses Ecto's `inspect` implementation
      assert log =~
               ~r<\[RESULT\] lib\/ex_unit\/capture_log\.ex:\d+: {:error, #Errors\.LogTest\.CustomStruct\<id: 123, bar: #Errors.LogTest.OtherCustomStruct\<id: 789, name: \"Cool\", fooID: 0, \.\.\.\>, user_id: 456, \.\.\.\>}>
    end

    test "logs :ok atom" do
      log =
        capture_log([level: :info], fn ->
          result = :ok |> Errors.log(:all)
          assert result == :ok
        end)

      assert log =~ ~r<\[RESULT\] test/errors/log_test\.exs:\d+: :ok>
    end

    test "logs {:ok, value}" do
      log =
        capture_log([level: :info], fn ->
          result = {:ok, "success"} |> Errors.log(:all)
          assert result == {:ok, "success"}
        end)

      assert log =~ ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:ok, \"success\"}>
    end

    test "logs nested custom structs in ok tuples" do
      log =
        capture_log([level: :info], fn ->
          {:ok,
           %CustomStruct{
             id: 123,
             foo: "thing",
             user_id: 456,
             bar: %OtherCustomStruct{id: 789, name: "Cool", something: "hi", fooID: 000}
           }}
          |> Errors.log(:all)
        end)

      # Uses Ecto's `inspect` implementation
      assert log =~
               ~r<\[RESULT\] lib\/ex_unit\/capture_log\.ex:\d+: {:ok, #Errors\.LogTest\.CustomStruct\<id: 123, bar: #Errors.LogTest.OtherCustomStruct\<id: 789, name: \"Cool\", fooID: 0, \.\.\.\>, user_id: 456, \.\.\.\>}>
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

      assert log =~ ~r<\[RESULT\] lib/errors/test_helper\.ex:\d+: {:error, "test"}>

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
          {:error, "test"} |> Errors.log()
        end)

      # With no app configured, it defaults to the first level up
      assert log =~ ~r<\[RESULT\] lib/ex_unit/capture_log\.ex:\d+: {:error, "test"}>
    end

    test ":error logs at level: :error" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :error], fn ->
          :error |> Errors.TestHelper.run_log(:errors)
        end)

      assert log =~ ~r<\[RESULT\] lib/errors/test_helper\.ex:\d+: :error>

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
          :error |> Errors.log()
        end)

      assert log =~ ~r<\[RESULT\] :error>
    end

    # :ok results
    test "{:ok, _} logs at level: :info - shows app line if app configured" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :info], fn ->
          {:ok, "test"} |> Errors.TestHelper.run_log(:all)
        end)

      assert log =~ ~r<\[RESULT\] lib/errors/test_helper\.ex:9: {:ok, "test"}>

      # Should not appear at warning level
      log =
        capture_log([level: :notice], fn ->
          {:ok, "test"} |> Errors.TestHelper.run_log(:all)
        end)

      refute log =~ ~r<RESULT>
    end

    test "{:ok, _} logs at level: :info - shows best default line if app not configured " do
      log =
        capture_log([level: :info], fn ->
          {:ok, "test"} |> Errors.log(:all)
        end)

      # With no app configured, it defaults to the first level up
      assert log =~ ~r<\[RESULT\] lib/ex_unit/capture_log\.ex:\d+: {:ok, "test"}>
    end

    test ":ok logs at level: :info" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :info], fn ->
          :ok |> Errors.TestHelper.run_log(:all)
        end)

      assert log =~ ~r<\[RESULT\] lib/errors/test_helper\.ex:9: :ok>

      # Should not appear at warning level
      log =
        capture_log([level: :notice], fn ->
          :ok |> Errors.TestHelper.run_log(:all)
        end)

      refute log =~ "RESULT"
    end

    test "app configured, but :ok result occurs where stacktrace does not have app" do
      Application.put_env(:errors, :app, :errors)

      log =
        capture_log([level: :info], fn ->
          :ok |> Errors.log(:all)
        end)

      assert log =~ ~r<\[RESULT\] :ok>
    end

    test "no logs at any level if :ok result and mode is :errors" do
      log =
        capture_log([level: :debug], fn ->
          :ok |> Errors.log()
        end)

      refute log =~ "RESULT"

      log =
        capture_log([level: :debug], fn ->
          {:ok, 123} |> Errors.log()
        end)

      refute log =~ "RESULT"
    end
  end
end
