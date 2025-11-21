# Control Flow

Sometimes you have an result and you want to transform it:

* Performing an actions if the previous was successful
* Returning an error when getting a specific success response (e.g. a HTTP 500)
* Transforming one error into another
* Ignoring an error result (i.e. turning it into a success)

In these cases you can use `Triage.ok_then`, `Triage.ok_then!` to error_then :ok results and `Triage.error_then` to error_then :error results.

The `ok_then` functions work under the assumption that you're going to return another success, so whatever result you return will be wrapped in an `{:ok, _}` tuple when returned.  Similarly, `error_then` will wrap the result in an `{:error, _}` tuple.  But if you return `:error` results from `ok_then` or `:ok` results from `error_then` then no wrapping occurs. This is so that you can have a flow where changes from the norm (:ok -> :error or :error -> :ok) stand out from the rest of the flow.

## `ok_then` and `ok_then!`

The `ok_then` functions provide a way to chain operations that return results. They allow you to build pipelines of transformations where errors automatically short-circuit the chain.

### `ok_then/1` - Execute a function + error_then exceptions

Takes a zero-arity function and executes it.  The function can return `:ok`, `{:ok, term()}`, `:error`, or `{:error, term()}`, but any other value is treated as `{:ok, <value>}`.

If an exception is raised then a `{:ok, WrappedError.t()}` is returned which wraps the exception.

```elixir
# order_id is defined / passed in
Triage.ok_then(fn -> fetch_order_from_api(order_id) end)
```

### `ok_then!/2` - Chaining operations + allowing exceptions to raise

Takes a result and a function, executing the function only if the result is successful. Unlike `ok_then/2`, this does **not** catch exceptions:

```elixir
# Example: User registration pipeline
fetch_order_from_api(order_id)
|> Triage.ok_then!(&validate_order/1)
|> Triage.ok_then!(fn order -> change_for_order(order, user.payment_info) end)
# => {:ok, user} if all thens succeed
# If any ok_then returns an error, further thens are ignored and the error is passed through

# When given :ok, passes nil to the function
# Previous ok_then returns `:ok`
|> Triage.ok_then!(fn nil -> send_notification() end)
# => {:ok, notification_result}
```

### `ok_then/2` - Chaining operations + handling exceptions

Behaves like `ok_then!/2` but catches exceptions and wraps them in a `WrappedError`:

```elixir
# Example: Processing an API response
{:ok, response}
|> Triage.ok_then(fn response -> Jason.decode!(response.body) end)  # Might raise
|> Triage.ok_then(&validate_schema/1)
|> Triage.ok_then(&transform_data/1)
# => {:ok, transformed_data}

# Catches exceptions during parsing
{:ok, config_string}
|> Triage.ok_then(&String.to_integer/1)  # Raises if not a valid integer
|> Triage.ok_then(&update_config/1)      # Never called if parsing raises
|> Triage.log()
```

Log output when String.to_integer/1 raises:

```
[error] [RESULT] lib/my_app/config.ex:42: ** (ArgumentError) errors were found at the given arguments:

 * 1st argument: not a textual representation of an integer

    [CONTEXT] :erlang.binary_to_integer/1
```

## `error_then`

The `Triage.error_then/2` function takes in a result and uses a callback function to determine how error results should be handled, passing ok results through unchanged.

```elixir
# Imagine this function returns either:
#  * {:ok, Confirmation.t()}
#  * {:error, :invoice_invalid}
#  * {:error, :credit_card_expired}
#  * {:error, :billing_service_down}
bill_customer(customer, invoice)
|> Triage.error_then(fn
  :invoice_invalid ->
    {:invoice_invalid, invoice_errors(invoice)}

  :billing_service_down ->
    # Queue for billing later

    {:ok, :bill_later}

  other ->
    other
end)
# Returns:
#  * {:ok, Confirmation.t()}
#  * {:ok, :bill_later}
#  * {:error, {:invoice_invalid, ...}}
#  * {:error, :credit_card_expired}
```

An exception with a function which returns an error result with an exception reason:

```elixir
Jason.decode(string)
# Jason returns a `Jason.DecodeError` exception struct
# Here we call Elixir's `Exception.message/1` to turn it into a string
|> Triage.error_then(fn error -> Exception.message(error) end)
```

You can use `Triage.error_then/2` to transform the error based on pattern matching. Here's an example combining `ok_then` and `error_then`:

```elixir
HTTPoison.get(url)
|> Triage.ok_then(fn
  %HTTPoison.Response{status_code: 200, body: body} ->
    body

  %HTTPoison.Response{status_code: 404, body: body} ->
    {:error, "Server result not found"}
end)
|> Triage.error_then(fn
    %HTTPoison.Error{reason: :nxdomain} ->
      "Server domain not found"

    %HTTPoison.Error{reason: :econnrefused}
      "Server connection refused"

    %HTTPoison.Error{reason: reason}
      "Unexpected error connecting to server: #{inspect(reason)}"
end)
```

Or you can provide a default value on failure:

```elixir
Jason.decode(string)
|> Triage.error_then(fn _ -> {:ok, @default_result} end)
```

> [!NOTE]
> You might be wondering why you might use `ok_then` / `error_then` functions instead of `with`.  If so, check out the [Comparison to with](comparison-to-with.html) section.
