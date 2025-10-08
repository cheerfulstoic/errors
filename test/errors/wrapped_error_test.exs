defmodule Errors.WrappedErrorTest do
  use ExUnit.Case
  alias Errors.WrappedError

  import ExUnit.CaptureLog

  describe "Exception.message" do
    test "binary reason" do
      wrapped_error = %WrappedError{
        reason: "original error message",
        context: "fobbing a widget"
      }

      expected_message = ~S[WRAPPED ERROR (fobbing a widget) "original error message"]

      assert Exception.message(wrapped_error) == expected_message
    end

    test "atom reason" do
      wrapped_error = %WrappedError{
        reason: :original_error_status,
        context: "fobbing a widget"
      }

      expected_message = ~S[WRAPPED ERROR (fobbing a widget) :original_error_status]

      assert Exception.message(wrapped_error) == expected_message
    end

    defmodule TestWithMessageKeyError do
      defexception [:message]
    end

    test "reason is exception with message key" do
      wrapped_error = %WrappedError{
        reason: %TestWithMessageKeyError{message: "the message which was set"},
        context: "fobbing a widget"
      }

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
      wrapped_error = %WrappedError{
        reason: %TestWithMessageCallbackError{status: :unknown},
        context: "fobbing a widget"
      }

      expected_message =
        ~S[WRAPPED ERROR (fobbing a widget) Errors.WrappedErrorTest.TestWithMessageCallbackError: 🤷]

      assert Exception.message(wrapped_error) == expected_message
    end

    test "nested reason is exception with message callback" do
      wrapped_error = %WrappedError{
        reason: %WrappedError{
          reason: %TestWithMessageCallbackError{status: :unknown},
          context: "lower down"
        },
        context: "higher up"
      }

      expected_message =
        ~S[WRAPPED ERROR (higher up => lower down) Errors.WrappedErrorTest.TestWithMessageCallbackError: 🤷]

      assert Exception.message(wrapped_error) == expected_message
    end

    defmodule TestWithoutMessageError do
      defexception [:status]
    end

    test "reason is exception with no ability to get a message" do
      wrapped_error = %WrappedError{
        reason: %TestWithoutMessageError{status: :unknown},
        context: "fobbing a widget"
      }

      expected_message = """
      Error when trying: fobbing a widget

      Errors.WrappedErrorTest.TestWithoutMessageError: %Errors.WrappedErrorTest.TestWithoutMessageError{status: :unknown}
      """

      log =
        capture_log([level: :warning], fn ->
          assert Exception.message(wrapped_error) == expected_message
        end)

      assert log =~
               "Exception module `Errors.WrappedErrorTest.TestWithoutMessageError` doesn't have a `message` key or implement a `message/1` callback"
    end
  end
end
