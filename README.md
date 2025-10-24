# Errors

A lightweight Elixir library for enhanced handling of **results** (`{:ok, _}` / `:ok` / `{:error, _}` / `:error`) with context wrapping, logging, and user message generation.

## Features

This package provides three levels of working with errors which are all **usable independently**, but which all complement each other.

- **Context Wrapping**: Add meaningful context to errors as they bubble up through your application
- **Result Logging**: Log errors (and optionally successes) with file/line information
- **User-friendly errors**: Be able to collapse errors into a single user error message

The design goal was to use standard return results and standard tools like Elixir Exception structs so that you never end up with anything out of the ordinary.

## Installation

Add `errors` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:errors, "~> 0.1.0"}
  ]
end
```

## Usage

### Context Wrapping

The `wrap_context/3` function adds context (a label + optional metadata) to any errors which come out of a piece of code. This is especially useful for understanding where a failure came from:

```elixir
defmodule Users do
  alias MyApp.{User, Repo}

  def create_user(params) do
    with :ok <- check_email_availability(params)
         {:ok, changeset} <- User.changeset(%User{}, params)
      Repo.insert(changeset)
    end
    |> Errors.wrap_context("create user", %{email: params[:email]})
  end
end

# When an error occurs, you get a `reason` which is a `Errors.WrappedError` exception struct.
{:error, reason} = Users.create_user(%{name: "Alice", email: "alice@example.com"})

# `Exception.message/1` is a standard Elixir function for getting message strings from exceptions
Exception.message(reason)
# => {:error, #Ecto.Changeset<...>}
#        [CONTEXT] lib/my_app/users.ex:10: create user
```

See the description of `Errors.user_message` below for how wrapped errors can be useful without you needing to work with them directly.

### Logging

The `log/2` function logs results and passes them through unchanged, making it perfect for debugging pipelines.

#### Logging Errors Only (the default)

```elixir
defmodule API.UserController do
  def create(conn, params) do
    Users.create_user(params)
    # Only logs if there's an error
    |> Errors.log()
    # You can also pass :errors (the default)
    # |> Errors.log(:errors)
    |> case do
      {:ok, user} ->
        conn
        |> render("user.json", user: user)
      # Ideally we should return a useful error... see below!
      {:error, _} ->
        conn
        |> put_status(400)
        |> json(%{error: "Unable to create user"})
    end
  end
end
```

When `Users.create_user` returns an error, a log is written at the `error` log level:

```
# [error] [RESULT] lib/api/user_controller.ex:4: {:error, #Ecto.Changeset<...>}
```

#### Logging All Results (`:all` mode)

In the case above, instead of calling `|> log(:errors)`  we could call `|> log(:all)`. In that case we could get the error log above, or we could get a success result written to the log at the `info` level:

```
# [info] [RESULT] lib/api/user_controller.ex:4: {:ok, %MyApp.Users.User{...}}
```

### Contexts

When errors occur deep in your application's call stack, it can be challenging to understand where your errors are coming from. The `wrap_context/3` function allows you to add contextual information at multiple levels, building up a trail of breadcrumbs as errors bubble up.

Here's an example showing how contexts accumulate across different modules:

```elixir
defmodule MyApp.OrderProcessor do
  def process_payment(order) do
    with {:ok, payment_method} <- fetch_payment_method(order),
         {:ok, charge} <- charge_payment(payment_method, order.amount) do
      {:ok, charge}
    end
    |> Errors.wrap_context("process payment", %{order_id: order.id, order_amount: order.amount})
  end
  # ...
end

defmodule MyApp.OrderService do
  def complete_order(order_id) do
    fetch_order(order_id)
    |> MyApp.OrderProcessor.process_payment(order)
    |> Errors.wrap_context("complete order")
  end
  # ...
end
```

When an error occurs in the payment processing, logging it will show the full context chain:

```elixir
def show(conn, %{"order_id" => order_id}) do
  order_id = String.to_integer(order_id)

  MyApp.complete_order(order_id)
  |> Errors.log()
  # ...

# Log output:
# [error] [RESULT] lib/my_app/order_service.ex:15: {:error, :payment_declined}
#     [CONTEXT] lib/my_app/order_service.ex:15: complete order
#     [CONTEXT] lib/my_app/order_processor.ex:8: process payment | %{order_id: 12345, amount: 99.99}
```

This makes it easy to trace exactly what your application was doing when the error occurred, including both descriptive labels and relevant data.

### User-friendly output

It's possible that you might have some code, be it in a LiveView, controller, background worker, etc... Often code at this "top level" might have called a series of functions which call a further series of functions, all of which can potentially return ok/error results.  When getting back `{:error, _}` tuples specifically, often the value inside of the tuple could be one of many things (e.g. a string/atom/struct/exception, etc...) Often the simplest thing to do is to return something like `There was an error: #{inspect(reason)}`, but that value often won't make sense to the user.  So we should find a way to make it human-readable, whenever possible.

```elixir
defmodule MyAppWeb.UserController do
  def checkout(conn, params) do
    MyApp.Users.create_user(params)
    |> case do
      {:ok, result} ->
        conn
        |> render("checkout.json", result: result)
      # Ideally we should return a useful error... see below!
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: Errors.user_message(reason)})
    end
    # ...
```

In this case, you could imagine that `MyApp.Users.create_user(params)` could return one of the following errors:

```elixir
# A string
{:error, "Could not contact tracking server"}
# An atom
{:error, :user_not_found}
# A struct containing errors
{:error, %Ecto.Changeset{...}}
# An exception value
{:error, %Jason.DecodeError{...}
```

`Errors.user_message` always turns the `reason` into a string and does it's best to extract the appropriate data for a human-readable string.

Additionally, if you use `Errors.wrap_context`, additional information from the `WrappedError` will be available to help describe the error.

### Steps

The `step` functions provide a way to chain operations that return results. They allow you to build pipelines of transformations where errors automatically short-circuit the chain.

#### `step!/1` - Execute a function + allowing exceptions to raise

Takes a zero-arity function and executes it.  The function can return `:ok`, `{:ok, term()}`, `:error`, or `{:error, term()}`, but any other value is treated as `{:ok, <value>}`

```elixir
# order_id is defined / passed in
Errors.step!(fn -> fetch_order_from_api(order_id) end)
```

#### `step!/2` - Chaining operations + allowing exceptions to raise

Takes a result and a function, executing the function only if the result is successful. Unlike `step/2`, this does **not** catch exceptions:

```elixir
# Example: User registration pipeline
Errors.step!(fn -> fetch_order_from_api(order_id) end)
|> Errors.step!(&validate_order/1)
|> Errors.step!(fn order -> change_for_order(order, user.payment_info) end)
# => {:ok, user} if all steps succeed
# If any step returns an error, further steps are ignored and the error is passed through

# When given :ok, passes nil to the function
# Previous step returns `:ok`
|> Errors.step!(fn nil -> send_notification() end)
# => {:ok, notification_result}
```

#### `step/2` - Chaining operations + handling exceptions

Behaves like `step!/2` but catches exceptions and wraps them in a `WrappedError`:

```elixir
# Example: Processing an API response
{:ok, response}
|> Errors.step(fn response -> Jason.decode!(response.body) end)  # Might raise
|> Errors.step(&validate_schema/1)
|> Errors.step(&transform_data/1)
# => {:ok, transformed_data}

# Catches exceptions during parsing
{:ok, config_string}
|> Errors.step(&String.to_integer/1)  # Raises if not a valid integer
|> Errors.step(&update_config/1)      # Never called if parsing raises
|> Errors.log()
```

Log output when String.to_integer/1 raises:

```
[error] [RESULT] lib/my_app/config.ex:42: ** (ArgumentError) errors were found at the given arguments:

 * 1st argument: not a textual representation of an integer

    [CONTEXT] :erlang.binary_to_integer/1
```

**When to use which:**

- Use `step!/2` when you want exceptions to propagate (fail fast)
- Use `step/2` when you want to handle exceptions as errors in your pipeline
- Use `step!/1` to normalize function returns into result tuples

### Mapping

The `map` functions provide a way to apply operations to each element in a collection wrapped in a result tuple. They allow you to transform collections while handling errors for individual elements.

#### `map!/2` - Map over collections + allowing exceptions to raise

Takes a result tuple containing a collection and a function that returns result tuples. Maps the function over each element, allowing exceptions to propagate:

```elixir
order_line_items
|> Errors.map!(&validate_line_item/1)
```

If, instead, there was an `InvalidError` raised, the map would stop where that happened. This is useful if you'd rather fail than have something processed halfway.

#### `map/2` - Map over collections + handling exceptions

Behaves like `map!/2` but catches exceptions and wraps them in `WrappedError`.  Useful when you want to make sure you process everything but also want to know when things fail.

```elixir
# `fetch_users/1` returns {:ok, [...]} or :error
fetch_users(user_ids)
|> Errors.map(fn user ->
  if user.email_verified do
    # Returns :ok or raises an exception
    send_email(user)
  else
    {:error, :email_not_verified}
  end
end)

# Result where one user hasn't validated email and one email timed out while sending
# WrappedError wraps a %MyApp.EmailClient.TimeoutError{}
# [:ok, {:error, :email_not_verified}, {:error, %Errors.WrappedError{...}}]

# If the initial fetch fails, the error passes through unchanged:
{:error, :user_service_unavailable}
|> Errors.map!(fn user -> send_email(user) end)
# => {:error, :user_service_unavailable}
```

With the list of results, you may want to just get the error results:

```elixir
|> Enum.filter(&Errors.error?/1)
```

Or you may want to split the ok and error results:

```elixir
|> Enum.split_with(&Errors.ok?/1)
|> case do
  {successes, []} ->
    # No errors
    # ...

  {successes, errors} ->
    # Some errors
  end
```

### Logging JSON

By default, logs are formatted as human-readable plain text. If you would like to output JSON logs, you can use a library like [`logger_json`](https://github.com/Nebo15/logger_json). The `Errors.log` function sets the `errors_result_details` metadata key as well as setting metadata given by `wrap_context` calls.  You can set these keys as output in your [logger configuration](https://hexdocs.pm/logger/Logger.html#module-metadata).  The `errors_result_details` key gives nested a key/value structure, so it won't be outputted with default logs and makes sense when outputting structured logs like with `json`.

Here is an example of configuring metadata:

```elixir
# config/config.exs
config :logger, :console,
 format: "[$level] $message $metadata\n",
 metadata: [:user_id]
```

To configure `logger_json`, you might use something like this:

```elixir
config :logger, :default_handler,
  formatter:
    LoggerJSON.Formatters.Basic.new(metadata: [:user_id, :errors_result_details])
```

If you were to use `Errors.wrap_context("updating user", user_id: 123)`:

With standard logging you'd get `user_id=123` just like if you gave the metadata to `Logger.error` yourself.

Here is an example of what you might get with `logger_json` (spacing introduced for readability):

```json
{
  "message": "[RESULT] {:error, :not_found}\n    [CONTEXT] updating user %{user_id: 123}",
  "time": "2025-10-24T13:20:06.885Z",
  "metadata": {
    "errors_result_details": {
      "reason": "not_found",
      "type": "error"
    },
    "user_id": 123
  },
  "severity": "error"
}
```

## Configuration

### `app`

Because of how tail-call optimisation affects stack-traces in Elixir, logging a result may not give the right line.  An example is when you give an anonymous function to a library:

```elixir
defmodule MyAppWeb.UserController do
  def create(conn, params) do
    SomeLibrary.execute(fn ->
      MyApp.Users.create_user(params)
      |> Errors.log()
    end)
  end
end


# The line in the log might look something like:
# [error] [RESULT] lib/some_library.ex:4: {:error, #Ecto.Changeset<...>}

# Where you would like it to show:
# [error] [RESULT] lib/my_app_web/user_controller.ex:5: {:error, #Ecto.Changeset<...>}
```

In order to help log the correct entries from the stacktrace, you can optionally configure your app's name to help it be found:

```elixir
# config/config.exs
config :errors, :app, :your_app_name
```

## Development

Run tests:

```bash
mix test
```

Run tests in watch mode (uses [`mix_test_interactive`](https://hex.pm/packages/mix_test_interactive):

```bash
mix test.interactive
```

## License

Copyright (c) 2025

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the LICENSE file for more details.
