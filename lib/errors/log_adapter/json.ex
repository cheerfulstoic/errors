defmodule Errors.LogAdapter.JSON do
  alias Errors.Stacktrace

  use Errors.LogAdapter

  @impl Errors.LogAdapter
  def call(log_details) do
    level = if(log_details.result_details.type == "error", do: :error, else: :info)

    stacktrace_line =
      log_details.stacktrace
      |> Stacktrace.most_relevant_entry()
      |> Stacktrace.format_file_line()

    {
      level,
      json_mod().encode!(%{
        source: "Errors",
        stacktrace_line: stacktrace_line,
        result_details: log_details.result_details
      })
    }
  end

  defp json_mod do
    Application.get_env(:errors, :json, Jason)
  end
end
