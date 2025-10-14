defmodule Errors.LogAdapter.Plain do
  alias Errors.Stacktrace

  use Errors.LogAdapter

  @impl Errors.LogAdapter
  def call(%{result: result} = log_details) do
    level = if(log_details.result_details.type == "error", do: :error, else: :info)

    stacktrace_line =
      log_details.stacktrace
      |> Stacktrace.most_relevant_entry()
      |> Stacktrace.format_file_line()

    parts_string =
      [stacktrace_line, log_details.result_details.message]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(": ")

    {level, "[RESULT] #{parts_string}"}
  end
end
