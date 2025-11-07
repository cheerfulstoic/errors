```elixir
  defp validate_each_metric(metrics, query) do
    Enum.reduce_while(metrics, [], fn metric, acc ->
      case validate_metric(metric, query) do
        {:ok, metric} -> {:cont, acc ++ [metric]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
```

```elixir
  defp validate_each_metric(metrics, query) do
    # Returns {:ok, [...]} where the original returned just [...]
    Triage.map_if(metrics, & validate_metric(&1, query))
  end
```
