defmodule Errors.WrappedErrorTest do
  use ExUnit.Case
  alias Errors.WrappedError

  import ExUnit.CaptureLog

  describe ".new" do
    test ":error" do
      %WrappedError{} = wrapped_error = WrappedError.new(:error, "fobbing a widget", [])

      assert wrapped_error.result == :error
      assert wrapped_error.reason == nil
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.message == ":error\n    [CONTEXT] fobbing a widget"

      # keyword list
      %WrappedError{} = wrapped_error = WrappedError.new(:error, "fobbing a widget", [], a: 1)

      assert wrapped_error.result == :error
      assert wrapped_error.reason == nil
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{a: 1}
      assert wrapped_error.message == ":error\n    [CONTEXT] fobbing a widget"

      # map
      %WrappedError{} = wrapped_error = WrappedError.new(:error, "fobbing a widget", [], %{a: 1})

      assert wrapped_error.result == :error
      assert wrapped_error.reason == nil
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{a: 1}
      assert wrapped_error.message == ":error\n    [CONTEXT] fobbing a widget"
    end

    test "{:error, _}" do
      %WrappedError{} =
        wrapped_error = WrappedError.new({:error, :something}, "fobbing a widget", [])

      assert wrapped_error.result == {:error, :something}
      assert wrapped_error.reason == :something
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.message == "{:error, :something}\n    [CONTEXT] fobbing a widget"

      # keyword list
      %WrappedError{} =
        wrapped_error = WrappedError.new({:error, :something}, "fobbing a widget", [], a: 1)

      assert wrapped_error.result == {:error, :something}
      assert wrapped_error.reason == :something
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{a: 1}
      assert wrapped_error.message == "{:error, :something}\n    [CONTEXT] fobbing a widget"

      # map
      %WrappedError{} =
        wrapped_error = WrappedError.new({:error, :something}, "fobbing a widget", [], %{a: 1})

      assert wrapped_error.result == {:error, :something}
      assert wrapped_error.reason == :something
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{a: 1}
      assert wrapped_error.message == "{:error, :something}\n    [CONTEXT] fobbing a widget"
    end

    test "fails with other inputs" do
      assert_raise(
        ArgumentError,
        "Errors wrap either :error or {:error, _}, got: :ok",
        fn ->
          WrappedError.new(:ok, "fobbing a widget", [])
        end
      )

      assert_raise(
        ArgumentError,
        "Errors wrap either :error or {:error, _}, got: {:ok, 123}",
        fn ->
          WrappedError.new({:ok, 123}, "fobbing a widget", [])
        end
      )

      assert_raise ArgumentError,
                   "Errors wrap either :error or {:error, _}, got: :some_error",
                   fn ->
                     WrappedError.new(:some_error, "fobbing a widget", [])
                   end
    end
  end

  describe ".message" do
    test "binary reason" do
      wrapped_error = WrappedError.new({:error, "original error message"}, "fobbing a widget", [])

      assert Exception.message(wrapped_error) ==
               "{:error, \"original error message\"}\n    [CONTEXT] fobbing a widget"
    end

    test "atom reason" do
      wrapped_error = WrappedError.new({:error, :original_error_status}, "fobbing a widget", [])

      assert Exception.message(wrapped_error) ==
               "{:error, :original_error_status}\n    [CONTEXT] fobbing a widget"
    end

    defmodule TestWithMessageKeyError do
      defexception [:message]
    end

    test "reason is exception with message key" do
      wrapped_error =
        WrappedError.new(
          {:error, %TestWithMessageKeyError{message: "the message which was set"}},
          "fobbing a widget",
          []
        )

      assert Exception.message(wrapped_error) ==
               "Errors.WrappedErrorTest.TestWithMessageKeyError: the message which was set\n    [CONTEXT] fobbing a widget"
    end

    defmodule TestWithMessageCallbackError do
      defexception [:status]

      def message(%__MODULE__{status: :unknown}), do: "🤷"
      def message(%__MODULE__{status: status}), do: inspect(status)
    end

    test "reason is exception with message callback" do
      wrapped_error =
        WrappedError.new(
          {:error, %TestWithMessageCallbackError{status: :unknown}},
          "fobbing a widget",
          []
        )

      assert Exception.message(wrapped_error) ==
               "Errors.WrappedErrorTest.TestWithMessageCallbackError: 🤷\n    [CONTEXT] fobbing a widget"
    end

    test "nested reason is exception with message callback" do
      wrapped_error =
        WrappedError.new(
          {
            :error,
            WrappedError.new(
              {:error, %TestWithMessageCallbackError{status: :unknown}},
              "lower down",
              []
            )
          },
          "higher up",
          []
        )

      assert Exception.message(wrapped_error) ==
               "Errors.WrappedErrorTest.TestWithMessageCallbackError: 🤷\n    [CONTEXT] higher up\n    [CONTEXT] lower down"
    end

    defmodule TestWithoutMessageError do
      defexception [:status]
    end

    test "reason is exception with no ability to get a message" do
      wrapped_error =
        WrappedError.new(
          {:error, %TestWithoutMessageError{status: :unknown}},
          "fobbing a widget",
          []
        )

      log =
        capture_log([level: :warning], fn ->
          assert Exception.message(wrapped_error) ==
                   "Errors.WrappedErrorTest.TestWithoutMessageError: %Errors.WrappedErrorTest.TestWithoutMessageError{status: :unknown}\n    [CONTEXT] fobbing a widget"
        end)

      assert log =~
               "Exception module `Errors.WrappedErrorTest.TestWithoutMessageError` doesn't have a `message` key or implement a `message/1` callback"
    end
  end
end
