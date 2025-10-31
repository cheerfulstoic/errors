defmodule Triage.String do
  @moduledoc false

  @alphanumeric_graphemes String.graphemes("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

  def generate(length) do
    @alphanumeric_graphemes
    |> Enum.take_random(length)
    |> Enum.join()
  end
end
