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

You could just introduce an `else`

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

This gets into the [Complex `else` clauses in `with`](https://hexdocs.pm/elixir/code-anti-patterns.html#complex-else-clauses-in-with) anti-pattern where it becomes hard to keep track of which `else` clause handles which `with` clause. Also to make sure you've covered all cases you need to dig into `function1`/`function2`/`function3`, which often isn't trivial.

## Real Examples

### A Simple Example

Let's take an example from the ["Complex `else` clauses in `with`"](https://hexdocs.pm/elixir/code-anti-patterns.html#complex-else-clauses-in-with) anti-pattern documentation. The following two functions were extracted from `with` clauses to make sure that the responses are standardized across clauses:

```elixir
defp file_read(path) do
  case File.read(path) do
    {:ok, contents} -> {:ok, contents}
    {:error, _} -> {:error, :badfile}
  end
end

defp base_decode64(contents) do
  case Base.decode64(contents) do
    {:ok, decoded} -> {:ok, decoded}
    :error -> {:error, :badencoding}
  end
end
```

This is an excellent idea and it's one of the problems `triage` tries to solve.

We can imagine refactoring these functions to use further `with` clauses:

```elixir
defp file_read(path) do
  with {:error, _} <- File.read(path) do
    {:error, :badfile}
  end
end

defp base_decode64(contents) do
  with :error <- Base.decode64(contents) do
    {:error, :badencoding}
  end
end
```

This has the advantage of making it very explicit which pattern we're doing something with and which pattern we're just passing through unchanged.

On the other hand, some people might not be comfortable:

* ...using `with` in a "non-standard" way (matching on :error results instead of :ok results)
* ...using `with` with just one clause
* ...not being explicit with each case (and, to be fair, there is sometimes value in a `case` raising a `MatchError`  if a path isn't covered)

```elixir
defp file_read(path) do
  File.read(path)
  |> Triage.error_then(fn _ -> :badfile end)
end

defp base_decode64(contents) do
  Base.decode64(contents)
  # Note: error_then/2 receives `nil` for bare `:error` atom results
  |> Triage.error_then(fn nil -> :badencoding end)
end
```

Here we simplify the error handling logic and move it to the end so it reads top-to-bottom. We also get similar behavior to `case` where we get a `MatchError` if a pattern isn't accounted for.

### A More Complex Example

Finally, let's take an [example from `oban`'s source code](https://github.com/oban-bg/oban/blob/d1789f166f77a5ae8e6548efa1431ed7199e1e63/lib/oban/engines/basic.ex#L428-L448):

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

This definitely requires a lot from the reader if they need to figure out which `else` clause matches up with which `with` clause. And, in fact, there are two cases which return `nil`. If we dig down into each function which is called in the `with` clauses we find:

* `unique_query` returns `{:ok, _, _}` or `nil`
* `acquire_lock` returns `:ok` or `{:error, :locked}`
* `fetch_job` returns `{:ok, job}` or `nil`
* `resolve_conflict` returns `{:ok, job}`, `{:ok, Ecto.Schema.t()}`, `{:error, Ecto.Changeset.t()}`

Aside from having a complex `else` clause, two of the functions return `nil` in some cases. If a function returns `:ok` / `{:ok, _}`, it's clearer to make sure it's always returning some sort of `:ok` / `:error` result. In this case we could return `{:error, :not_found}` to indicate the failure. So, how might we put this code another way? We can use the `Triage.ok_then!/2` and `Triage.error_then/2` functions, which work with `:ok` and `:error` results, respectively:

```elixir
defp insert_unique(conf, changeset, opts) do
  opts = Keyword.put(opts, :on_conflict, :nothing)

  # Need to refactor `unique_query` to return `{:ok, {query, lock_key}}`
  unique_query(changeset)
  |> Triage.ok_then!(fn {query, lock_key} ->
    acquire_lock(conf, lock_key)
    |> Triage.error_then(fn
      :locked ->
        Changeset.apply_action(changeset, :insert)
        |> Triage.ok_then!(& %{&1 | conflict?: true})
    end)
    |> Triage.ok_then!(fn _ -> fetch_job(conf, query, opts) end)
  end)
  |> Triage.ok_then!(& resolve_conflict(conf, &1, changeset, opts))
  # Assuming we refactor `unique_query` and `fetch_job` to return `{:error, :not_found}` instead of `nil`
  |> Triage.ok_then!(fn job -> %{job | conflict?: true} end)
  |> Triage.error_then(fn :not_found -> {:ok, Repo.insert(conf, changeset, opts)} end)
end
```

At first glance this doesn't seem as clean because it doesn't have all of the happy-path cases followed by all of the error handling. But this version has several advantages:

* We're focused on the values from the `{:ok, _}` / `{:error, _}` tuples without dealing with pattern matching on them.
* Tuples are only specified when we're turning a success into an error or vice-versa which makes those special cases stand out.
* Error handling is done at the soonest point that it can be handled (just after the call or after calls that might share the same error).
* Nesting makes it clear where the `query` variable is needed.
* We can use `ok_then` (not used above, but used instead of `ok_then!`) to catch errors, if we don't want a particular step to crash.

-----

Am I trying to convince you to use this?  Kind of... but only if it makes sense for the situation!
