# Contexts



## Context Wrapping

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

## Logging

The `log/2` function logs results and passes them through unchanged, making it perfect for debugging pipelines.

### Logging Errors Only (the default)

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

### Logging All Results (`:all` mode)

In the case above, instead of calling `|> log(:errors)`  we could call `|> log(:all)`. In that case we could get the error log above, or we could get a success result written to the log at the `info` level:

```
# [info] [RESULT] lib/api/user_controller.ex:4: {:ok, %MyApp.Users.User{...}}
```

## Contexts

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

## User-friendly output

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

