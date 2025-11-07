```elixir
  defp validate_filters(site, filters) do
    Enum.reduce_while(filters, :ok, fn filter, _ ->
      case validate_filter(site, filter) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
```

```elixir
  defp validate_filters(site, filters) do
    Triage.all(filters, & validate_filter(site, &1))
  end
```
