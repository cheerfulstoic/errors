defmodule Errors.TestHelper do
  @moduledoc false

  # This is a weird solution, but this exists because in some tests we need to have some
  # module in the stacktrace which is part of the app configure via `config :errors, :app`

  @doc false
  def run_log(result, mode) do
    new_result = Errors.log(result, mode)

    blah()

    new_result
  end

  def blah do
    123
  end

  def raise_argument_error(_) do
    raise ArgumentError, "amount too high"
  end
end
