defmodule Errors.WrappedErrorTest do
  use ExUnit.Case
  alias Errors.WrappedError

  import ExUnit.CaptureLog

  describe ".new" do
    test ":error" do
      %WrappedError{} = wrapped_error = WrappedError.new(:error, "fobbing a widget")

      assert wrapped_error.result == :error
      assert wrapped_error.reason == nil
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.message == "WRAPPED ERROR (fobbing a widget) nil"

      %WrappedError{} = wrapped_error = WrappedError.new(:error, "fobbing a widget", %{a: 1})

      assert wrapped_error.result == :error
      assert wrapped_error.reason == nil
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{a: 1}
      assert wrapped_error.message == "WRAPPED ERROR (fobbing a widget) nil"
    end

    test "{:error, _}" do
      %WrappedError{} = wrapped_error = WrappedError.new({:error, :something}, "fobbing a widget")

      assert wrapped_error.result == {:error, :something}
      assert wrapped_error.reason == :something
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{}
      assert wrapped_error.message == "WRAPPED ERROR (fobbing a widget) :something"

      %WrappedError{} =
        wrapped_error = WrappedError.new({:error, :something}, "fobbing a widget", %{a: 1})

      assert wrapped_error.result == {:error, :something}
      assert wrapped_error.reason == :something
      assert wrapped_error.context == "fobbing a widget"
      assert wrapped_error.metadata == %{a: 1}
      assert wrapped_error.message == "WRAPPED ERROR (fobbing a widget) :something"
    end

    test "fails with other inputs" do
      assert_raise ArgumentError,
                   "Errors wrap either :error or {:error, _}, got: :ok",
                   fn ->
                     WrappedError.new(:ok, "fobbing a widget")
                   end

      assert_raise ArgumentError,
                   "Errors wrap either :error or {:error, _}, got: {:ok, 123}",
                   fn ->
                     WrappedError.new({:ok, 123}, "fobbing a widget")
                   end

      assert_raise ArgumentError,
                   "Errors wrap either :error or {:error, _}, got: :some_error",
                   fn ->
                     WrappedError.new(:some_error, "fobbing a widget")
                   end
    end
  end

  describe ".message" do
    test "binary reason" do
      wrapped_error = WrappedError.new({:error, "original error message"}, "fobbing a widget")

      expected_message = ~S[WRAPPED ERROR (fobbing a widget) "original error message"]

      assert Exception.message(wrapped_error) == expected_message
    end

    test "atom reason" do
      wrapped_error = WrappedError.new({:error, :original_error_status}, "fobbing a widget")

      expected_message = ~S[WRAPPED ERROR (fobbing a widget) :original_error_status]

      assert Exception.message(wrapped_error) == expected_message
    end

    defmodule TestWithMessageKeyError do
      defexception [:message]
    end

    test "reason is exception with message key" do
      wrapped_error =
        WrappedError.new(
          {:error, %TestWithMessageKeyError{message: "the message which was set"}},
          "fobbing a widget"
        )

      expected_message =
        ~S[WRAPPED ERROR (fobbing a widget) Errors.WrappedErrorTest.TestWithMessageKeyError: the message which was set]

      assert Exception.message(wrapped_error) == expected_message
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
          "fobbing a widget"
        )

      expected_message =
        ~S[WRAPPED ERROR (fobbing a widget) Errors.WrappedErrorTest.TestWithMessageCallbackError: 🤷]

      assert Exception.message(wrapped_error) == expected_message
    end

    test "nested reason is exception with message callback" do
      wrapped_error =
        WrappedError.new(
          {
            :error,
            WrappedError.new(
              {:error, %TestWithMessageCallbackError{status: :unknown}},
              "lower down"
            )
          },
          "higher up"
        )

      expected_message =
        ~S[WRAPPED ERROR (higher up => lower down) Errors.WrappedErrorTest.TestWithMessageCallbackError: 🤷]

      assert Exception.message(wrapped_error) == expected_message
    end

    defmodule TestWithoutMessageError do
      defexception [:status]
    end

    test "reason is exception with no ability to get a message" do
      expected_message =
        ~S[WRAPPED ERROR (fobbing a widget) Errors.WrappedErrorTest.TestWithoutMessageError: %Errors.WrappedErrorTest.TestWithoutMessageError{status: :unknown}]

      {wrapped_error, log} =
        with_log([level: :warning], fn ->
          WrappedError.new(
            {:error, %TestWithoutMessageError{status: :unknown}},
            "fobbing a widget"
          )
        end)

      log =
        capture_log([level: :warning], fn ->
          assert Exception.message(wrapped_error) == expected_message
        end)

      assert log =~
               "Exception module `Errors.WrappedErrorTest.TestWithoutMessageError` doesn't have a `message` key or implement a `message/1` callback"
    end
  end
end
