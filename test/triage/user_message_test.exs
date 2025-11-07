defmodule Triage.UserMessageTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "Just passes strings through" do
    assert Triage.user_message({:error, "There was a really weird error"}) ==
             "There was a really weird error"
  end

  test "Atom" do
    {result, log} =
      with_log([level: :error], fn -> Triage.user_message({:error, :some_error_atom}) end)

    assert result =~ ~r/There was an error\. Refer to code: [A-Z0-9]{8}/
    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)
    assert log =~ ~r/#{code}: Could not generate user error message. Error was: :some_error_atom/
  end

  test "Exception" do
    {result, log} =
      with_log(fn ->
        Triage.user_message({:error, %RuntimeError{message: "an example error message"}})
      end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8}/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: #RuntimeError<\.\.\.> \(message: an example error message\)/
  end

  test "WrappedError - originally string" do
    exception =
      Triage.WrappedError.new({:error, "The original message"}, "fooing the bar", [
        # Made up stacktrace line using a real module so we get a realistic-ish line/number
        {Triage.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
      ])

    assert Triage.user_message({:error, exception}) ==
             "The original message (happened while: fooing the bar)"

    exception =
      Triage.WrappedError.new(
        {:error,
         Triage.WrappedError.new(
           {:error, "The original message"},
           "lower down",
           [
             {Triage.TestHelper, :made_up_function, 0,
              [file: ~c"lib/errors/test_helper.ex", line: 18]}
           ],
           %{foo: 123, bar: "baz"}
         )},
        "higher up",
        [
          {Triage.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ],
        %{something: %{whatever: :hello}}
      )

    assert Triage.user_message({:error, exception}) ==
             "The original message (happened while: higher up => lower down)"
  end

  test "WrappedError - originally atom" do
    exception =
      Triage.WrappedError.new({:error, :some_original_error}, "fooing the bar", [
        # Made up stacktrace line using a real module so we get a realistic-ish line/number
        {Triage.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
      ])

    {result, log} = with_log(fn -> Triage.user_message({:error, exception}) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: fooing the bar\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: :some_original_error/

    exception =
      Triage.WrappedError.new(
        {:error,
         Triage.WrappedError.new(
           {:error, :some_original_error},
           "lower down",
           [
             {Triage.TestHelper, :made_up_function, 0,
              [file: ~c"lib/errors/test_helper.ex", line: 18]}
           ],
           %{foo: 123, bar: "baz"}
         )},
        "higher up",
        [
          {Triage.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ],
        %{something: %{whatever: :hello}}
      )

    {result, log} = with_log(fn -> Triage.user_message({:error, exception}) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: higher up => lower down\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: :some_original_error/
  end

  test "WrappedError - originally exception" do
    exception =
      Triage.WrappedError.new(
        {:error, %RuntimeError{message: "an example error message"}},
        "fooing the bar",
        [
          # Made up stacktrace line using a real module so we get a realistic-ish line/number
          {Triage.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ]
      )

    {result, log} = with_log(fn -> Triage.user_message({:error, exception}) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: fooing the bar\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: #RuntimeError<\.\.\.> \(message: an example error message\)/
  end

  test "WrappedError - originally :error" do
    exception =
      Triage.WrappedError.new(
        {:error, :error},
        "fooing the bar",
        [
          # Made up stacktrace line using a real module so we get a realistic-ish line/number
          {Triage.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ]
      )

    {result, log} = with_log(fn -> Triage.user_message({:error, exception}) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: fooing the bar\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: :error/
  end
end
