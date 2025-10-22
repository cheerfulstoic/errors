defmodule Errors.Stacktrace do
  @moduledoc "Tools to get relevant stacktrace info for app using the Errors library"

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

      if index do
        Enum.at(stacktrace, index)
      end
    else
      List.first(stacktrace)
    end
  end

  def format_file_line(nil), do: nil

  def format_file_line({_mod, _func, _arity, location}) do
    file = Keyword.get(location, :file)
    line = Keyword.get(location, :line)

    cond do
      is_nil(file) -> nil
      is_nil(line) or line == 0 -> "#{file}"
      true -> "#{file}:#{line}"
    end
  end
end
