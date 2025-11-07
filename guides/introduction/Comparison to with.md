# Comparison to `with`

Because this package sometimes deals with sequences steps which return ok/error results, a common question is "why not just use the `with` clause?". The truth is, sometimes `with` is great, but most people assume that `with` is for handling ok/error results when that is just the most common use-case.  `with` is a more general tool and if you don't understand how it works, it may have unexpected behavior.

Here is an example that demonstrates a few potential gotchas with the `with` clause:

```elixir
with {:ok, a} <- function1(...),
     {:ok, %{"b" => b} <- function2(a),
     {:ok, c} <- function3(b) do
  # ...
end
```

Let's imagine a few things that might happen which could be unexpected.  Imagine that:

----

**`function1` sometimes returns `{:ok, _}` and `:ok` other times**

You might imagine that you'd get a `MatchError`, but actually the whole `with` clause will simply return `:ok` without running `function2`, `function3`, or the body.

You might think it would be weird for a function to return inconsistent `:ok` results, but it could be that `function1` returns the result of multiple functions that **it's** calling.

----

**`function2` sometimes returns `{:ok, map()}` but the map doesn't have a `"b"` key**

Again, the `with` will return `{:ok, <map>}` without running `function3` or the body.

This could happen particularly when the function is getting a JSON response from a server and your app has no control over that response.

----

**`function2` returns `:error` but `function1` and `function3` return `{:error, reason}`**

This means that your `with` is going to return an inconsistent error result.

## You could just introduce an `else`

```elixir
with {:ok, a} <- function1(...),
     {:ok, %{"b" => b} <- function2(a),
     {:ok, c} <- function3(b) do
  # ...
else
  :ok ->
    # ...

  {:ok, value} ->
    # ...

  :error ->
    {:error, ...}
end
```

This gets into the [Complex `else` clauses in `with`](https://hexdocs.pm/elixir/code-anti-patterns.html#complex-else-clauses-in-with) anti-pattern where it becomes hard to keep track of which `else` clause is there because of which of the one or more `with` clauses.

**MORE TO COME, WORK IN PROGRESS...**

## Real Example

Let's take an [example from `oban`](https://github.com/oban-bg/oban/blob/d1789f166f77a5ae8e6548efa1431ed7199e1e63/lib/oban/engines/basic.ex#L428-L448)

```elixir
  defp insert_unique(conf, changeset, opts) do
    opts = Keyword.put(opts, :on_conflict, :nothing)

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
  end
```

```elixir
defp insert_unique(conf, changeset, opts) do
  opts = Keyword.put(opts, :on_conflict, :nothing)

  # Need to refactor `unique_query` to return `{:ok, {query, lock_key}}`
  unique_query(changeset)
  |> Triage.then!(fn {query, lock_key} ->
    acquire_lock(conf, lock_key)
    |> Triage.handle(fn
      :locked ->
        Changeset.apply_action(changeset, :insert)
        |> Triage.then!(& %{&1 | conflict?: true})
    end)
    |> Triage.then!(fn _ -> fetch_job(conf, query, opts) end)
  end)
  |> Triage.then!(& resolve_conflict(conf, &1, changeset, opts))
  # Assuming we refactor `unique_query` and `fetch_job` to return `{:error, :not_found}` instead of `nil`
  |> Triage.then!(fn job -> %{job | conflict?: true} end)
  |> Triage.handle(fn :not_found -> {:ok, Repo.insert(conf, changeset, opts)} end)
end
```
