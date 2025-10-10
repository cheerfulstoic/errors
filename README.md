# Errors

A lightweight Elixir library for enhanced handling of **results** (`{:ok, _}`/`:ok`/`{:error, _}`/`:error`) with context wrapping, logging, and user message generation.

## Features

This package provides three levels of working with errors which are **all usable independently of each other**:

- **Context Wrapping**: Add meaningful context to errors as they bubble up through your application
- **Result Logging**: Log errors (and optionally successes) with file/line information
- **User-friendly errors**: Be able to collapse errors into a single user error message

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

The `wrap_context/3` function adds context (a label + optional metadata) to any errors which come out of a piece of code.
This is especially useful for understanding where a failure came from:

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

# When an error occurs, you get rich context:
{:error, wrapped_error} = Users.create_user(%{name: "Alice", email: "alice@example.com"})
Exception.message(wrapped_error)
# => [CONTEXT: create user] {:error, %Ecto.Changeset{...}}
```

### Logging

The `log/2` function logs results and passes them through unchanged,
making it perfect for debugging pipelines.

#### Logging Errors Only (`:errors` mode)

```elixir
defmodule API.UserController do
  def create(conn, params) do
    Users.create_user(params)
    |> Errors.log(:errors)  # Only logs if there's an error
    |> case do
      {:ok, user} -> render(conn, "user.json", user: user)
      # Ideally we should return a useful error... see below!
      {:error, _} -> send_resp(conn, 400, "Unable to create user")
    end
  end
end

# When Users.create_user returns an error, a log is written at the `error` log level:

# [error] [RESULT] (lib/api/user_controller.ex:4) {:error, %Ecto.Changeset{...}}
```

#### Logging All Results (`:all` mode)

In the case above, instead of calling `Errors.log(:errors)`  we could call `Errors.log(:all)`. In that case we could get the error log above, or we could get a success result written to the log at the `info` level:

```elixir
# [info] [RESULT] (lib/api/user_controller.ex:4) {:ok, %MyApp.Users.User{...}}
```

#### Configuring your app name

Because of the way stacktraces work in Elixir, logging a result may not give the right line.  An example is when you give an anonymous function to a library:

```elixir
defmodule MyAppWeb.UserController do
  def create(conn, params) do
    SomeLibrary.execute(fn ->
      MyApp.Users.create_user(params)
      |> Errors.log(:errors)
    end)
    # ...

# The line in the log might look something like:
# [info] [RESULT] (lib/some_library.ex:4) {:error, %Ecto.Changeset{...}}
# Where you would like it to show:
# [info] [RESULT] (lib/my_app_web/user_controller.ex:5) {:error, %Ecto.Changeset{...}}
```

In order to help log the correct entries from the stacktrace, you can optionally configure our app's name to help it be found:

```elixir
# config/config.exs
config :errors, :app, :your_app_name
```

### User-friendly output

It's possible that you might have some code, be it in a LiveView, controller, background worker, etc...
Often code at this "top level" might have called a series of functions which call a further series of functions,
all of which can potentially return ok/error results.  When getting back `{:error, _}` tuples specifically,
often the value inside of the tuple could be one of many things (e.g. a string/atom/struct/exception, etc...)
Often the simplest thing to do is to return something like `There was an error: #{inspect(reason)}`, but
that value often won't make sense to the user.  So we should find a way to make it human-readable, whenever possible.

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

**Configuration:**

```elixir
# config/config.exs
config :errors, :app, :my_app_name
```

## Development

Run tests:

```bash
mix test
```

Run tests in watch mode:

```bash
mix test.interactive
```

## License

Copyright (c) 2025

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the LICENSE file for more details.
