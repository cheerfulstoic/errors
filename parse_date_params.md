```elixir
  defp parse_date_params(params) do
    params
    |> Map.take(["from", "to", "date"])
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case Date.from_iso8601(value) do
        {:ok, date} ->
          {:cont, {:ok, Map.put(acc, key, date)}}

        _ ->
          {:halt,
           {:error,
            "Failed to parse '#{key}' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"}}
      end
    end)
  end
```

```elixir
  defp parse_date_params(params) do
    params
    |> Map.take(["from", "to", "date"])
    |> Errors.reduce(%{}, fn {key, value}, acc ->
      case Date.from_iso8601(value) do
        {:ok, date} ->
          Map.put(acc, key, date)

        _ ->
          {:error, "Failed to parse '#{key}' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"}
      end
    end)
  end
```

```elixir
  defp parse_date_params(params) do
    params
    |> Map.take(["from", "to", "date"])
    |> Map.new(fn {key, value} ->
      case Date.from_iso8601(value) do
        {:ok, date} ->
          {key, date}

        _ ->
          throw {:error, "Failed to parse '#{key}' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"}
    end)
  catch
    {:error, _} = error ->
      error
  end
```

```elixir
  defp parse_date_params(params) do
    params
    |> Map.take(["from", "to", "date"])
    |> Triage.map_if(fn {key, value} ->
      Date.from_iso8601(params[key])
      # Might be worth using `then`, as `Date.from_iso8601` raises if given something other than a string
      # but that might be what you want!
      # Triage.then(fn -> Date.from_iso8601(params[key]) end)
      |> Triage.then(& {key, &1})
      |> Triage.handle(fn _ -> "Failed to parse '#{key}' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`" end)
    end)
    |> Triage.then(&Map.new/1)
  end
```

