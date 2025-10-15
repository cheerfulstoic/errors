defmodule Errors.UserMessageTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "Just passes strings through" do
    assert Errors.user_message("There was a really weird error") ==
             "There was a really weird error"
  end

  test "Atom" do
    {result, log} = with_log([level: :error], fn -> Errors.user_message(:some_error_atom) end)

    assert result =~ ~r/There was an error\. Refer to code: [A-Z0-9]{8}/
    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)
    assert log =~ ~r/#{code}: Could not generate user error message. Error was: :some_error_atom/
  end

  test "Exception" do
    {result, log} =
      with_log(fn -> Errors.user_message(%RuntimeError{message: "an example error message"}) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8}/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: #RuntimeError<\.\.\.> \(message: an example error message\)/
  end

  test "WrappedError - originally string" do
    exception =
      Errors.WrappedError.new({:error, "The original message"}, "fooing the bar", [
        # Made up stacktrace line using a real module so we get a realistic-ish line/number
        {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
      ])

    assert Errors.user_message(exception) ==
             "The original message (happened while: fooing the bar)"

    exception =
      Errors.WrappedError.new(
        {:error,
         Errors.WrappedError.new(
           {:error, "The original message"},
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

    assert Errors.user_message(exception) ==
             "The original message (happened while: higher up => lower down)"
  end

  test "WrappedError - originally atom" do
    exception =
      Errors.WrappedError.new({:error, :some_original_error}, "fooing the bar", [
        # Made up stacktrace line using a real module so we get a realistic-ish line/number
        {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
      ])

    {result, log} = with_log(fn -> Errors.user_message(exception) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: fooing the bar\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: :some_original_error/

    exception =
      Errors.WrappedError.new(
        {:error,
         Errors.WrappedError.new(
           {:error, :some_original_error},
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

    {result, log} = with_log(fn -> Errors.user_message(exception) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: higher up => lower down\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: :some_original_error/
  end

  test "WrappedError - originally exception" do
    exception =
      Errors.WrappedError.new(
        {:error, %RuntimeError{message: "an example error message"}},
        "fooing the bar",
        [
          # Made up stacktrace line using a real module so we get a realistic-ish line/number
          {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ]
      )

    {result, log} = with_log(fn -> Errors.user_message(exception) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: fooing the bar\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: #RuntimeError<\.\.\.> \(message: an example error message\)/
  end

  test "WrappedError - originally :error" do
    exception =
      Errors.WrappedError.new(
        {:error, :error},
        "fooing the bar",
        [
          # Made up stacktrace line using a real module so we get a realistic-ish line/number
          {Errors.TestHelper, :run_log, 2, [file: ~c"lib/errors/test_helper.ex", line: 10]}
        ]
      )

    {result, log} = with_log(fn -> Errors.user_message(exception) end)

    assert result =~
             ~r/There was an error\. Refer to code: [A-Z0-9]{8} \(happened while: fooing the bar\)/

    [_, code] = Regex.run(~r/Refer to code: ([A-Z0-9]{8})/, result)

    assert log =~
             ~r/#{code}: Could not generate user error message. Error was: :error/
  end
end
