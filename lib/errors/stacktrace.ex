defmodule Errors.Stacktrace do
  # Using a macro so that this helper function isn't part of the stacktrace
  defmacro calling_stacktrace do
    quote do
      {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

      # Skip `Process.info` line and the `Errors.log` line:
      Enum.drop(stacktrace, 2)
    end
  end

  def most_relevant_entry(stacktrace) do
    if app = Application.get_env(:errors, :app) do
      index =
        Enum.find_index(stacktrace, fn {mod, _, _, _} ->
          match?({:ok, ^app}, :application.get_application(mod))
        end)

      Enum.at(stacktrace, index || 0)
    else
      List.first(stacktrace)
    end
  end
end
