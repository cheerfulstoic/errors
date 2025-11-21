[Source for original code](https://github.com/plausible/analytics/blob/ce424bf436d6e42eac7bd8ed66af720174905f2f/extra/lib/plausible/installation_support/checks/url.ex#L50-L63)

The following case uses `reduce_while` to check two domains via DNS:

```elixir
  # Check A records of the the domains [domain, "www.#{domain}"]
  # at this point, domain can contain path
  @spec find_working_url(String.t()) :: {:ok, String.t()} | {:error, :domain_not_found}
  defp find_working_url(domain) do
    [domain_without_path | rest] = split_domain(domain)

    [
      domain_without_path,
      "www.#{domain_without_path}"
    ]
    |> Enum.reduce_while({:error, :domain_not_found}, fn d, _acc ->
      case dns_lookup(d) do
        :ok -> {:halt, {:ok, "https://" <> unsplit_domain(d, rest)}}
        {:error, :no_a_record} -> {:cont, {:error, :domain_not_found}}
      end
    end)
  end
```

Using `find_value`, `ok_then`, and `error_then` we can reduce the `reduce_while` boilerplate:

```elixir
  # Check A records of the the domains [domain, "www.#{domain}"]
  # at this point, domain can contain path
  @spec find_working_url(String.t()) :: {:ok, String.t()} | {:error, :domain_not_found}
  defp find_working_url(domain) do
    [domain_without_path | rest] = split_domain(domain)

    [
      domain_without_path,
      "www.#{domain_without_path}"
    ]
    |> Triage.find_value(&dns_lookup/1)
    |> Triage.ok_then(& "https://" <> unsplit_domain(&1, rest))
    |> Triage.error_then(fn :no_a_record -> :domain_not_found end)
  end
```
