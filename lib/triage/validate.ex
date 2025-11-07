defmodule Triage.Validate do
  @moduledoc false

  def validate_result!(result, strict_or_loose, label \\ "Argument")

  def validate_result!(:ok, _, _), do: nil
  def validate_result!(:error, _, _), do: nil
  def validate_result!({:ok, _}, _, _), do: nil
  def validate_result!({:error, _}, _, _), do: nil

  def validate_result!(result, :loose, _)
      # when is_tuple(result) and tuple_size(result) >= 3 and elem(result, 0) in [:ok, :error] do
      when is_tuple(result) and elem(result, 0) in [:ok, :error] do
    nil
  end

  def validate_result!(result, :strict, label) do
    raise ArgumentError,
          "#{label} must be {:ok, _} / :ok / {:error, _} / :error, got: #{inspect(result)}"
  end

  def validate_result!(result, :loose, label) do
    raise ArgumentError,
          "#{label} must be {:ok, ...} / :ok / {:error, ...} / :error, got: #{inspect(result)}"
  end
end
