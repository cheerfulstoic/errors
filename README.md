# Triage

A lightweight Elixir library for enhanced handling of **results** (`{:ok, _}` / `:ok` / `{:error, _}` / `:error`) with context wrapping, logging, and user message generation.

## Features

This package provides three levels of working with errors which are all **usable independently**, but which all complement each other.

- **Context Wrapping**: Add meaningful context to errors as they bubble up through your application
- **Result Logging**: Log errors (and optionally successes) with file/line information
- **User-friendly errors**: Be able to collapse errors into a single user error message
- **Error control flow**: `then` and `handle` functions help control and transform results
- **Error enumeration**: functions like `map_unless`, `find_value`, and `all` help deal with enumerations over data where each iteration may succeed or fail.

Design goals:

The design goal was to use standard return results and standard tools like Elixir Exception structs so that you never end up with anything out of the ordinary.

Make sure to see [the HexDocs](https://hexdocs.pm/triage/) for function descriptions, example use-cases, and the design philosophy.

## Examples

### Contexts

When an error is returned (e.g. in a tuple, as opposed to being raised), often that error can be passed up a stack and soon the context of where it came from can be lost. Triage offers a `wrap_context` function to attach a context string and/or metadata to errors via a `WrappedError` exception struct, as well as `log` and `user_message` functions which can take advantage of this extra information to assist debugging.

Note that while the `user_message` function supports turning `WrappedError` structs into useful human-readable strings, it supports giving user error messages for any error tuple.

```elixir
defmodule MyApp.OrderProcessor do
  def process_payment(order) do
    with {:ok, payment_method} <- fetch_payment_method(order),
         {:ok, charge} <- charge_payment(payment_method, order.amount) do
      {:ok, charge}
    end
    |> Triage.wrap_context("process payment", %{order_id: order.id, order_amount: order.amount})
  end
  # ...
end

defmodule MyApp.OrderService do
  def complete_order(order_id) do
    fetch_order(order_id)
    |> MyApp.OrderProcessor.process_payment(order)
    |> Triage.wrap_context("complete order")
  end
  # ...
end

def show(conn, %{"order_id" => order_id}) do
  order_id = String.to_integer(order_id)

  MyApp.complete_order(order_id)
  |> Triage.log()
  |> case do
    {:ok, value} ->
      # ...

    {:error, reason} ->
      conn
      |> put_status(400)
      |> json(%{error: Triage.user_message(reason)})
  end
  # ...

# Output from `Triage.log()`:

# [error] [RESULT] lib/my_app/order_service.ex:15: {:error, :payment_declined}
#     [CONTEXT] lib/my_app/order_service.ex:15: complete order
#     [CONTEXT] lib/my_app/order_processor.ex:8: process payment | %{order_id: 12345, amount: 99.99}
```

Any metadata given to `log` is also assigned to the [Logger metadata](https://hexdocs.pm/logger/Logger.html#module-metadata) in addition to being outputted.

Make sure to see the [Contexts section of the docs](https://hexdocs.pm/triage/contexts.html) for more information.

<https://hexdocs.pm/triage/contexts.html>

### Enumeration

`triage` has a set of functions to help when you have a series of step which might succeed or fail.  As an example, you may want to build up a list, but return an error if anything fails.

```elixir
  defp validate_each_metric(metrics, query) do
    Enum.reduce_while(metrics, {:ok, []}, fn metric, {:ok, acc} ->
      case validate_metric(metric, query) do
        {:ok, metric} -> {:cont, {:ok, acc ++ [metric]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
```

The `Triage.map_unless` function is one tool available:

```elixir
  defp validate_each_metric(metrics, query) do
    # Returns {:ok, [...]} where the original returned just [...]
    Triage.map_unless(metrics, & validate_metric(&1, query))
  end
```

For more functions and examples, see the [Enumerating Errors section of the docs](https://hexdocs.pm/triage/enumerating-errors.html).

### Control Flow

...EXAMPLES COMING SOON...SEE [THE DOCS](https://hexdocs.pm/triage/) FOR NOW...

## Installation

Add `triage` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:triage, "~> 0.2.0"}
  ]
end
```

## Usage

See [the docs](https://hexdocs.pm/triage) for detailed information about the different tools available.

## Development

Run tests:

```bash
mix test
```

Run tests in watch mode (uses [`mix_test_interactive`](https://hex.pm/packages/mix_test_interactive):

```bash
mix test.interactive
```

Or just:

```bash
mix test
```

## License

Copyright (c) 2025

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the LICENSE file for more details.
