defmodule Errors.Inspect do
  def inspect(value) do
    case Inspect.impl_for(value) do
      Inspect.Any ->
        shrunken_inspect(value)

      _ ->
        Kernel.inspect(value)
    end
  end

  defp shrunken_inspect(%mod{}) do
    "##{Kernel.inspect(mod)}<...>"
  end

  defp shrunken_inspect(value) do
    Kernel.inspect(value)
  end
end
