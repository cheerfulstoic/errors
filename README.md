# Errors

A lightweight Elixir library for enhanced handling of **results** (`{:ok, _}` / `:ok` / `{:error, _}` / `:error`) with context wrapping, logging, and user message generation.

## Features

This package provides three levels of working with errors which are all **usable independently**, but which all complement each other.

- **Context Wrapping**: Add meaningful context to errors as they bubble up through your application
- **Result Logging**: Log errors (and optionally successes) with file/line information
- **User-friendly errors**: Be able to collapse errors into a single user error message
- **Error control flow**: `then` and `handle` functions help control and transform results
- **Error enumeration**: functions like `map_unless`, `find_value`, and `all` help deal with enumerations over data where each iteration may succeed or fail.

The design goal was to use standard return results and standard tools like Elixir Exception structs so that you never end up with anything out of the ordinary.

Make sure to see [the HexDocs](https://hexdocs.pm/triage/) for function descriptions, example use-cases, and the design philosophy.

## Installation

Add `errors` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:triage, "~> 0.2.0"}
  ]
end
```

## Usage

See [TODO](the docs - NEED TO CREATE THIS!) for details information about the different tools available.

### Mapping

The `map` functions provide a way to apply operations to each element in a collection wrapped in a result tuple. They allow you to transform collections while handling errors for individual elements.

#### `map!/2` - Map over collections + allowing exceptions to raise

Takes a result tuple containing a collection and a function that returns result tuples. Maps the function over each element, allowing exceptions to propagate:

```elixir
order_line_items
|> Triage.map!(&validate_line_item/1)
```

If, instead, there was an `InvalidError` raised, the map would stop where that happened. This is useful if you'd rather fail than have something processed halfway.

#### `map/2` - Map over collections + handling exceptions

Behaves like `map!/2` but catches exceptions and wraps them in `WrappedError`.  Useful when you want to make sure you process everything but also want to know when things fail.

```elixir
# `fetch_users/1` returns {:ok, [...]} or :error
fetch_users(user_ids)
|> Triage.map(fn user ->
  if user.email_verified do
    # Returns :ok or raises an exception
    send_email(user)
  else
    {:error, :email_not_verified}
  end
end)

# Result where one user hasn't validated email and one email timed out while sending
# WrappedError wraps a %MyApp.EmailClient.TimeoutError{}
# [:ok, {:error, :email_not_verified}, {:error, %Triage.WrappedError{...}}]

# If the initial fetch fails, the error passes through unchanged:
{:error, :user_service_unavailable}
|> Triage.map!(fn user -> send_email(user) end)
# => {:error, :user_service_unavailable}
```

With the list of results, you may want to just get the error results:

```elixir
|> Enum.filter(&Triage.error?/1)
```

Or you may want to split the ok and error results:

```elixir
|> Enum.split_with(&Triage.ok?/1)
|> case do
  {successes, []} ->
    # No errors
    # ...

  {successes, errors} ->
    # Some errors
  end
```

### Logging JSON

By default, logs are formatted as human-readable plain text. If you would like to output JSON logs, you can use a library like [`logger_json`](https://github.com/Nebo15/logger_json). The `Triage.log` function sets the `errors_result_details` metadata key as well as setting metadata given by `wrap_context` calls.  You can set these keys as output in your [logger configuration](https://hexdocs.pm/logger/Logger.html#module-metadata).  The `errors_result_details` key gives nested a key/value structure, so it won't be outputted with default logs and makes sense when outputting structured logs like with `json`.

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

If you were to use `Triage.wrap_context("updating user", user_id: 123)`:

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
      |> Triage.log()
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
config :triage, :app, :your_app_name
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
