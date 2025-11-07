<https://github.com/oban-bg/oban/blob/main/lib/oban/engines/basic.ex#L31>

```elixir
  with :ok <- Enum.reduce_while(opts, :ok, &validate_meta_opt/2) do
    # ...
  end

  defp validate_meta_opt(opt, _acc) do
    case validate_meta_opt(opt) do
      {:error, error} -> {:halt, {:error, ArgumentError.exception(error)}}
      _ -> {:cont, :ok}
    end
  end

  defp validate_meta_opt({:limit, limit}) do
    if not (is_integer(limit) and limit > 0) do
      {:error, "expected :limit to be an integer greater than 0, got: #{inspect(limit)}"}
    end
  end

  defp validate_meta_opt({:paused, paused}) do
    if not is_boolean(paused) do
      {:error, "expected :paused to be a boolean, got: #{inspect(paused)}"}
    end
  end

  # etc...
```

```elixir
  case Enum.find_value(opts, &meta_opt_error/1) do
    nil ->
      # ...

    message ->
      {:error, ArgumentError.exception(error)}
      
  end

  defp meta_opt_error({:limit, limit}) do
    if not (is_integer(limit) and limit > 0) do
      "expected :limit to be an integer greater than 0, got: #{inspect(limit)}"
    end
  end

  defp meta_opt_error({:paused, paused}) do
    if not is_boolean(paused) do
      "expected :paused to be a boolean, got: #{inspect(paused)}"
    end
  end

  # etc...
```

