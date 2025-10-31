# Comparison to `with`

Because this package sometimes deals with sequences steps which return ok/error results, a common question is "why not just use the `with` clause?". The truth is, sometimes `with` is great, but most people assume that `with` is for handling ok/error results when that is just the most common use-case.  `with` is a more general tool and if you don't understand how it works, it may break in unexpected ways.

Here is an example that demonstrates a few potential gotchas with the `with` clause:

```elixir
with {:ok, a} <- function1(...),
     {:ok, %{"b" => b} <- function2(a),
     {:ok, c} <- function3(b) do
  # ...
end
```

Let's imagine a few things that might happen which could be unexpected.  Imagine that:

## `function1` sometimes returns `:ok` in addition to `{:ok, _}`

You might imagine that you'd get a `MatchError`, but actually the whole `with` clause will simply return `:ok` without running `function2`, `function3`, or the body.

## `function2` sometimes returns `{:ok, map()}` but the map doesn't have a `"b"` key

Again, the `with` will return `{:ok, <map>}` without running `function3` or the body

## `function2` returns `:error` but `function1` and `function3` return `{:error, reason}`

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
