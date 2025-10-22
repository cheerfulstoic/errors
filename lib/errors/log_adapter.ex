defmodule Errors.LogAdapter do
  defmodule LogDetails do
    defstruct [:result, :result_details, :stacktrace]

    def new(result, stacktrace) do
      %__MODULE__{
        result: result,
        result_details: Errors.result_details(result),
        stacktrace: stacktrace
      }
    end
  end

  @type log_level :: atom()

  @callback call(Errors.LogAdapter.LogDetails.t()) :: {log_level(), String.t(), keyword()} | nil

  defmacro __using__(_opts) do
    quote do
      @behaviour Errors.LogAdapter
    end
  end
end
