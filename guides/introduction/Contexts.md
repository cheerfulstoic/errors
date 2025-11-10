# Contexts

## Context Wrapping

The `wrap_context/3` function adds context (a label and/or metadata) to any errors which come out of a piece of code. This is especially useful for understanding where a failure came from:

```elixir
defmodule Users do
  alias MyApp.{User, Repo}

  def create_user(params) do
    with :ok <- check_email_availability(params)
         {:ok, changeset} <- User.changeset(%User{}, params)
      Repo.insert(changeset)
    end
    |> Triage.wrap_context("create user", %{email: params[:email]})
  end
end

# When an error occurs, you get a `reason` which is a `Triage.WrappedError` exception struct.
{:error, reason} = Users.create_user(%{name: "Alice", email: "alice@example.com"})

# `Exception.message/1` is a standard Elixir function for getting message strings from exceptions
Exception.message(reason)
# => {:error, #Ecto.Changeset<...>}
#        [CONTEXT] lib/my_app/users.ex:10: create user
```

You also might find yourself converting an error into another error in order to make it clear what was happening:

([source](https://github.com/anoma/anoma/blob/base/apps/anoma_client/lib/client/node/rpc.ex#L42-L48))

```elixir
case AdvertisementService.Stub.advertise(channel, request) do
    {:ok, intents} ->
      {:ok, intents}

    {:error, _} ->
      {:error, :failed_to_fetch_intents}
end
```

This could be a good time to use a context so that the original error is returned along with context label/metadata:

```elixir
AdvertisementService.Stub.advertise(channel, request)
|> Triage.wrap_context("Fetching advertisement intents", channel_host: channel.host)
```

Make sure to see the [Output section](output.html) for how wrapped errors can be useful without you needing to work with them directly.
