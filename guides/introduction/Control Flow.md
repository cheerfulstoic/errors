# Control Flow

Sometimes you have an result and you want to transform it:

* Performing an actions if the previous was successful
* Returning an error when getting a specific success response
* Transforming an error result
* Ignoring an error result (e.g. turning it into a success)

In these cases you can use `Triage.then`, `Triage.then!` to handle ok results and `Triage.handle` to handle error results.

## `then` / `then!`

The `then` functions provide a way to chain operations that return results. They allow you to build pipelines of transformations where errors automatically short-circuit the chain.

### `then!/1` - Execute a function + allowing exceptions to raise

Takes a zero-arity function and executes it.  The function can return `:ok`, `{:ok, term()}`, `:error`, or `{:error, term()}`, but any other value is treated as `{:ok, <value>}`

```elixir
# order_id is defined / passed in
Triage.then!(fn -> fetch_order_from_api(order_id) end)
```

### `then!/2` - Chaining operations + allowing exceptions to raise

Takes a result and a function, executing the function only if the result is successful. Unlike `then/2`, this does **not** catch exceptions:

```elixir
# Example: User registration pipeline
fetch_order_from_api(order_id)
|> Triage.then!(&validate_order/1)
|> Triage.then!(fn order -> change_for_order(order, user.payment_info) end)
# => {:ok, user} if all thens succeed
# If any then returns an error, further thens are ignored and the error is passed through

# When given :ok, passes nil to the function
# Previous then returns `:ok`
|> Triage.then!(fn nil -> send_notification() end)
# => {:ok, notification_result}
```

### `then/2` - Chaining operations + handling exceptions

Behaves like `then!/2` but catches exceptions and wraps them in a `WrappedError`:

```elixir
# Example: Processing an API response
{:ok, response}
|> Triage.then(fn response -> Jason.decode!(response.body) end)  # Might raise
|> Triage.then(&validate_schema/1)
|> Triage.then(&transform_data/1)
# => {:ok, transformed_data}

# Catches exceptions during parsing
{:ok, config_string}
|> Triage.then(&String.to_integer/1)  # Raises if not a valid integer
|> Triage.then(&update_config/1)      # Never called if parsing raises
|> Triage.log()
```

Log output when String.to_integer/1 raises:

```
[error] [RESULT] lib/my_app/config.ex:42: ** (ArgumentError) errors were found at the given arguments:

 * 1st argument: not a textual representation of an integer

    [CONTEXT] :erlang.binary_to_integer/1
```

**When to use which:**

* Use `then!/2` when you want exceptions to propagate (fail fast)
* Use `then/2` when you want to handle exceptions as errors in your pipeline
* Use `then!/1` to normalize function returns into result tuples

## `handle`

The `Triage.handle` function takes in a result uses a callback function to determine how error results should be handled, passing ok results through unchanged.

```elixir
Jason.decode(string)
# Jason returns a `Jason.DecodeError` exception struct
# Here we call Elixir's `Exception.message/1` to turn it into a string
|> Triage.handle(fn error -> Exception.message(error) end)
```

You can use `Triage.handle` to transform the error based on pattern matching:

```elixir
HTTPoison.get(url)
|> Triage.then(fn
  %HTTPoison.Response{status_code: 200, body: body} ->
    body

  %HTTPoison.Response{status_code: 404, body: body} ->
    {:error, "Server result not found"}
end)
|> Triage.handle(fn
    %HTTPoison.Error{reason: :nxdomain} ->
      "Server domain not found"

    %HTTPoison.Error{reason: :econnrefused}
      "Server connection refused"

    %HTTPoison.Error{reason: reason}
      "Unexpected error connecting to server: #{inspect(reason)}"
end)
```

Or you can ignore the error and return a success:

```elixir
Jason.decode(string)
|> Triage.handle(fn _ -> {:ok, @default_result} end)
```
