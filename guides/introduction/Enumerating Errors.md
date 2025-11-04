# Enumerating Errors

THIS PAGE UNDER CONSTRUCTION!

Triage.map??

Triage.map_until

Triage.all => :ok | :error | {:error, term()} (doesn't return results)
Triage.find_value

## `map_if`

[source for original example](https://github.com/plausible/analytics/blob/64aa2434e9b0e5836f5a47a9ec31bf57cd9da4d4/lib/plausible_web/controllers/api/external_stats_controller.ex#L141-L148)

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

Using `Enum.reduce_while` is a common pattern when operating over a set of [results](`t:Triage.result/0`).  In this case `validate_each_metric` returns a list if everything is successful while returning the first error if nothing is successful.

We can use the `Triage.map_if` function to simplify this logic:

```elixir
  defp validate_each_metric(metrics, query) do
    # Returns {:ok, [...]} where the original returned just [...]
    Triage.map_if(metrics, & validate_metric(&1, query))
  end
```

In addition to simplifying the code, it's more obvious at first glance what is happening because things have been stripped down to the most important details (`map_if` is being used on `metrics`, using `validate_metric`).

Also, by using `triage` there is an assurance that we will get a [results](`t:Triage.result/0`).

## find_value

[source for original example](https://github.com/plausible/analytics/blob/a44ce24867db2961c1523f6b5ff0bfb20bdf25b4/extra/lib/plausible/auth/sso/domain/verification.ex#L28-L39)

```elixir
Enum.reduce_while(methods, {:error, :unverified}, fn method, acc ->
  case apply(__MODULE__, method, [sso_domain, domain_identifier, opts]) do
    true -> {:halt, {:ok, method}}
    false -> {:cont, acc}
  end
end)
```

This is a case where we want to stop on **success**, not an **error**.  So we can use `Triage.find_value` to return the first successful result:

```elixir
Triage.find_value(methods, fn method ->
  if apply(__MODULE__, method, [sso_domain, domain_identifier, opts]) do
    {:ok, method}
  else
    {:error, :unverified}
  end
end)
```

Aside from reducing the code down to it's essentials, this also has the advantage of putting the error at the end in the context of the `if` / `else` statement.

## all

[source for original example](https://github.com/plausible/analytics/blob/a44ce24867db2961c1523f6b5ff0bfb20bdf25b4/lib/plausible/stats/filters/query_parser.ex#L695-L702)

```elixir
  defp validate_list(list, parser_function) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case parser_function.(value) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
```

Here we're looking to see if a function (`parser_function`) always returns a success or not.  For this we can use `Triage.all`:

```elixir
  defp validate_list(list, parser_function) do
    Triage.all(list, parser_function)
  end
```

Because this was simplified down to a single function call, it would even be possible to get rid of the `validate_list` function.  It's used in two places:

```elixir
validate_list(goal_filter_clauses, &validate_goal_filter(&1, configured_goal_names))
```

```elixir
with :ok <- validate_list(query.metrics, &validate_metric(&1, query)) do
```

Which can become:

```elixir
Triage.all(goal_filter_clauses, &validate_goal_filter(&1, configured_goal_names))
```

```elixir
with :ok <- Triage.all(query.metrics, &validate_metric(&1, query)) do
```

So really in this example, `validate_list` is just a general function doing the same thing as `Triage.all` would do
