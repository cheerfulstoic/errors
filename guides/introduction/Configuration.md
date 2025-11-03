# Configuration

# `app`

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

