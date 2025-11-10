```elixir
  defp reject_invalid_country_codes([_op, "visit:country", code_or_codes | _rest] = filter) do
    code_or_codes
    |> List.wrap()
    |> Enum.reduce_while(filter, fn
      value, _ when byte_size(value) == 2 -> {:cont, filter}
      _, _ -> {:halt, :error}
    end)
  end
```

```elixir
  defp reject_invalid_country_codes([_op, "visit:country", code_or_codes | _rest] = filter) do
    code_or_codes
    |> List.wrap()
    |> Triage.all(& byte_size(&1) == 2)
    # Changing the behavior so that `{:ok, filter}` is returned rather than just `filter`
    |> Triage.then(fn _ -> filter end)
    # Idea: allow Errors functions to take a 0-arity callback if we want to ignore
    # |> Triage.then(fn -> filter end)
  end
```

```elixir
  defp reject_invalid_country_codes([_op, "visit:country", code_or_codes | _rest] = filter) do
    code_or_codes
    |> List.wrap()
    |> Enum.all?(& byte_size(&1) == 2)
    |> case do
      true ->
        {:ok, filter}

      false ->
        :error
    end)
  end
```