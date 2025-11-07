From oban: lib/oban/engines/basic.ex:444

```elixir
  with {:ok, query, lock_key} <- unique_query(changeset),
        :ok <- acquire_lock(conf, lock_key),
        {:ok, job} <- fetch_job(conf, query, opts),
        {:ok, job} <- resolve_conflict(conf, job, changeset, opts) do
    {:ok, %{job | conflict?: true}}
  else
    {:error, :locked} ->
      with {:ok, job} <- Changeset.apply_action(changeset, :insert) do
        {:ok, %{job | conflict?: true}}
      end

    nil ->
      Repo.insert(conf, changeset, opts)

    error ->
      error
  end
```

```elixir
# Hrmmmmmmmm.... 🤔

# `conf`, `changeset`, and `opts` are available variables

# Need to refactor `unique_query` to return `{:ok, {query, lock_key}}`
unique_query(changeset)
|> Triage.then!(fn {query, lock_key} ->
  acquire_lock(conf, lock_key)
  |> Triage.handle(fn
    :locked ->
      with {:ok, job} <- Changeset.apply_action(changeset, :insert) do
        {:ok, %{job | conflict?: true}}
      end
  end)
  |> Triage.then!(fn _ -> fetch_job(conf, query, opts) end)
end)
# Assuming we refactor `unique_query` and `fetch_job` to return `{:error, :not_found}` instead of `nil`
|> Triage.handle(fn :not_found -> {:ok, Repo.insert(conf, changeset, opts)} end)
|> Triage.then!(fn job -> %{job | conflict?: true} end)

```

```
# Notes:
#  * I would match on `{:error, _} = error` at the end
#  * Not immediately clear which `else` clauses match which `with` clause outputs
#  * The functions are all private and are only used in this code
#    * Could extract
     * Extracting comes with the cost of code being spread out, when it's not being re-used

# unique_query returns `{:ok, _, _}` or `nil`
# acquire_lock returns `:ok` or `{:error, :locked}`
# fetch_job returns `{:ok, job}` or `nil`
# resolve_conflict returns `{:ok, job}`, `{:ok, Ecto.Schema.t()}`, `{:error, Ecto.Changeset.t()}
```

