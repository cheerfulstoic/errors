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

Exception.message(reason)
# => {:error, #Ecto.Changeset<...>}
#        [CONTEXT] lib/my_app/users.ex:10: create user
```

See the description of `Errors.user_message` below for how wrapped errors can be useful without you needing to work with them directly.

### Logging

The `log/2` function logs results and passes them through unchanged, making it perfect for debugging pipelines.

#### Logging Errors Only (`:errors` mode)

```elixir
defmodule API.UserController do
  def create(conn, params) do
    Users.create_user(params)
    |> Errors.log(:errors)  # Only logs if there's an error
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

# When Users.create_user returns an error, a log is written at the `error` log level:

# [error] [RESULT] lib/api/user_controller.ex:4: {:error, #Ecto.Changeset<...>}
```

#### Logging All Results (`:all` mode)

In the case above, instead of calling `|> log(:errors)`  we could call `|> log(:all)`. In that case we could get the error log above, or we could get a success result written to the log at the `info` level:

```elixir
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

  MyApp.complete_order.complete_order(order_id)
  |> Errors.log(:errors)
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

## API Reference

### `Errors.wrap_context/3`

```elixir
wrap_context(result, context, metadata \\ %{})
```

Wraps error results with context information. Success results pass through unchanged.

- `result` - `:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`
- `context` - A string describing what operation was being performed
- `metadata` - A map of additional metadata (optional)

Returns the original result if successful, or `{:error, %Errors.WrappedError{}}` if an error.

### `Errors.log/2`

```elixir
log(result, mode)
```

Logs results and passes them through unchanged.

- `result` - `:ok`, `{:ok, value}`, `:error`, or `{:error, reason}`
- `mode` - `:errors` (only log errors) or `:all` (log all results)

Returns the original result unchanged.

### `Errors.user_message/1`

- `reason` - Any `term()` value

## Configuration

### `app`

Because of how tail-call optimisation affects stack-traces in Elixir, logging a result may not give the right line.  An example is when you give an anonymous function to a library:

```elixir
defmodule MyAppWeb.UserController do
  def create(conn, params) do
    SomeLibrary.execute(fn ->
      MyApp.Users.create_user(params)
      |> Errors.log(:errors)
    end)
    # ...

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

### `log_adapter`

By default, logs are formatted as human-readable plain text. You can configure a different log adapter to change the output format. The library includes a JSON log adapter for structured logging:

```elixir
# config/config.exs
config :errors, :log_adapter, Errors.LogAdapter.JSON
```

With the JSON adapter enabled, logs will be output as JSON objects:

```elixir
# Example function with wrap_context:
defmodule MyApp.Users do
  def update_email(user_id, new_email) do
    user = get_user!(user_id)

    update_user(user, %{email: new_email})
    |> Errors.wrap_context("update email", %{user_id: user_id, email: new_email})
  end
end

# Usage:
MyApp.Users.update_email(123, "new@example.com")
|> Errors.log(:errors)
```

Plain text format (default):

```
[error] [RESULT] lib/my_app_web/user_controller.ex:15: {:error, #Ecto.Changeset<...>}
    [CONTEXT] lib/my_app/users.ex:42: update email | %{user_id: 123, email: "new@example.com"}
```

JSON format (spacing inserted for readability here):

```
[error] {
  "source": "Errors",
  "stacktrace_line": "lib/my_app_web/user_controller.ex:15",
  "result_details": {
    "type": "error",
    "value": {
      "__contexts__": [
        {
          "label":"update email",
          "metadata": {"user_id" 123, "email": "user@domain.com"},
          "stacktrace": [
            "(my_app 0.1.0) lib/my_app/users.ex:42: MyApp.Users.update_email/2",
            ...
          ]
        }
      ],
      "__root_reason__": {
        "__struct__": "Ecto.Changeset",
        "params": {
          "email": 123,
        },
        "errors": {
          "email": "{\"is invalid\", [type: :string, validation: :cast]}"
        },
        ...
      }
    },
    "message": "{:error, #Ecto.Changeset<...>}\n    [CONTEXT] lib/my_app/users.ex:42: update email %{user_id: 123, email: \"new@example.com\"}"
  }
}
```

You can also implement your own custom log adapter by using the `Errors.LogAdapter` behaviour.

### `json`

When using the JSON log adapter, you can configure which JSON library to use. By default, it uses `Jason`:

```elixir
# config/config.exs

# default
config :errors, :json, Jason
# Built-in JSON module in Elixir 1.18+
config :errors, :json, JSON
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
