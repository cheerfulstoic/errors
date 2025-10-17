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
             %{foo: 123, bar: "baz"}
           )},
          "higher up",
          [
            {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
          ],
          %{something: %{whatever: :hello}}
        )

      log =
        capture_log([level: :error], fn ->
          result = {:error, exception} |> Errors.log()
          assert result == {:error, exception}
        end)

      assert log =~
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: RuntimeError: an example error message
    \[CONTEXT\] lib/errors/test_helper.ex:10: higher up | %{foo: 123, bar: "baz"}
    \[CONTEXT\] lib/errors/test_helper.ex:18: lower down | %{something: %{whatever: :hello}}>

      # ~r<\[RESULT\] \(test/errors/log_test\.exs:\d+\) \[CONTEXT: higher up =\> lower down\] RuntimeError: an example error message>
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
               ~r<\[RESULT\] test/errors/log_test\.exs:\d+: {:error, #Ecto\.Changeset\<action: :insert, changes: %{}, errors: \[name: {"is invalid", \[type: :string, validation: :cast\]}\], data: #Errors\.LogTest\.User\<\>, valid\?: false, \.\.\.\>}>
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
               ~r<\[RESULT\] lib\/ex_unit\/capture_log\.ex:\d+: {:error, #Errors\.LogTest\.CustomStruct\<id: 123, bar: #Errors.LogTest.OtherCustomStruct\<id: 789, fooID: 0, name: \"Cool\", \.\.\.\>, user_id: 456, \.\.\.\>}>
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
               ~r<\[RESULT\] lib\/ex_unit\/capture_log\.ex:\d+: {:ok, #Errors\.LogTest\.CustomStruct\<id: 123, bar: #Errors.LogTest.OtherCustomStruct\<id: 789, fooID: 0, name: \"Cool\", \.\.\.\>, user_id: 456, \.\.\.\>}>
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

    # TODO: Show that :ok results don't log when logging :errors
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

  describe "JSON logging" do
    test ":ok" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

      log =
        capture_log([level: :info], fn ->
          :ok |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[info\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "ok"
      assert data["result_details"]["message"] == ":ok"
    end

    test "{:ok, _}" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

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

      [_, json] = Regex.run(~r/\[info\] (.*)/, log)

      # Make sure id comes first, __struct__ second, and everything else alphabetically
      assert json =~ ~r<"id":123,"__struct__":.*\"bar\":.*\"user_id\":>

      assert json =~ ~r<"id":789,"__struct__":.*\"fooID\":.*\"name\">

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "ok"

      assert data["result_details"]["message"] ==
               "{:ok, #Errors.LogTest.CustomStruct<id: 123, bar: #Errors.LogTest.OtherCustomStruct<id: 789, fooID: 0, name: \"Cool\", ...>, user_id: 456, ...>}"

      assert data["result_details"]["value"] == %{
               "__struct__" => "Errors.LogTest.CustomStruct",
               "id" => 123,
               "bar" => %{
                 "__struct__" => "Errors.LogTest.OtherCustomStruct",
                 "id" => 789,
                 "fooID" => 0,
                 "name" => "Cool"
               },
               "user_id" => 456
             }
    end

    test ":error" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

      log =
        capture_log([level: :info], fn ->
          :error |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[error\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "error"
      assert data["result_details"]["message"] == ":error"
    end

    test "{:error, %Ecto.Changeset.t()}" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

      log =
        capture_log([level: :info], fn ->
          %User{}
          |> Ecto.Changeset.cast(%{name: 1}, [:name])
          |> Ecto.Changeset.apply_action(:insert)
          |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[error\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "error"

      assert data["result_details"]["message"] ==
               "{:error, #Ecto.Changeset<action: :insert, changes: %{}, errors: [name: {\"is invalid\", [type: :string, validation: :cast]}], data: #Errors.LogTest.User<>, valid?: false, ...>}"

      assert data["result_details"]["value"] == %{
               "__struct__" => "Ecto.Changeset",
               "constraints" => [],
               "errors" => %{
                 "name" => "{\"is invalid\", [type: :string, validation: :cast]}"
               },
               "prepare" => [],
               "repo_opts" => [],
               "required" => [],
               "validations" => [],
               "params" => %{"name" => 1},
               "types" => %{"id" => "binary_id", "name" => "string"}
             }
    end

    test "{:error, Exception.t()}" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

      log =
        capture_log([level: :info], fn ->
          {:error, %CustomError{message: "custom error's message"}} |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[error\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "error"

      assert data["result_details"]["message"] ==
               "{:error, #Errors.LogTest.CustomError<...>} (message: custom error's message)"

      assert data["result_details"]["value"] == %{
               "__struct__" => "Errors.LogTest.CustomError",
               "__message__" => "custom error's message"
             }
    end

    test "{:error, Errors.WrappedError.t()}" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

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
             %{foo: 123, bar: "baz"}
           )},
          "higher up",
          [
            {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
          ],
          %{something: %{whatever: :hello}}
        )

      log =
        capture_log([level: :info], fn ->
          {:error, exception} |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[error\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "error"

      assert data["result_details"]["message"] ==
               "{:error, #RuntimeError<...>} (message: an example error message)\n    [CONTEXT] lib/errors/test_helper.ex:10: higher up %{something: %{whatever: :hello}}\n    [CONTEXT] lib/errors/test_helper.ex:18: lower down %{bar: \"baz\", foo: 123}"

      assert data["result_details"]["value"] == %{
               "__contexts__" => [
                 %{
                   "label" => "higher up",
                   "metadata" => %{},
                   "stacktrace" => [
                     "(errors 0.1.0) lib/errors/test_helper.ex:10: Errors.TestHelper.run_log/2"
                   ]
                 },
                 %{
                   "label" => "lower down",
                   "metadata" => %{},
                   "stacktrace" => [
                     "(errors 0.1.0) lib/errors/test_helper.ex:18: Errors.TestHelper.made_up_function/0"
                   ]
                 }
               ],
               "__root_reason__" => %{
                 "__message__" => "an example error message",
                 "__struct__" => "RuntimeError"
               }
             }
    end

    test "{:error, atom()}" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

      log =
        capture_log([level: :info], fn ->
          {:error, :the_error} |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[error\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "error"

      assert data["result_details"]["message"] == "{:error, :the_error}"

      assert data["result_details"]["value"] == "the_error"
    end

    test "{:error, String.t()}" do
      Application.put_env(:errors, :log_adapter, Errors.LogAdapter.JSON)

      log =
        capture_log([level: :info], fn ->
          {:error, "the error's message"} |> Errors.log(:all)
        end)

      [_, json] = Regex.run(~r/\[error\] (.*)/, log)

      data = Jason.decode!(json)

      assert data["source"] == "Errors"
      assert data["stacktrace_line"] =~ ~r[^lib/ex_unit/capture_log\.ex:\d+$]

      assert data["result_details"]["type"] == "error"

      assert data["result_details"]["message"] == "{:error, \"the error's message\"}"

      assert data["result_details"]["value"] == "the error's message"
    end
  end
end
