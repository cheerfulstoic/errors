```elixir
  @max_prop_key_length Plausible.Props.max_prop_key_length()
  @max_prop_value_length Plausible.Props.max_prop_value_length()
  defp validate_props(changeset) do
    case Changeset.get_field(changeset, :props) do
      props ->
        Enum.reduce_while(props, changeset, fn
          {key, value}, changeset
          when byte_size(key) > @max_prop_key_length or
                 byte_size(value) > @max_prop_value_length ->
            {:halt,
             Changeset.add_error(
               changeset,
               :props,
               "keys should have at most #{@max_prop_key_length} bytes and values #{@max_prop_value_length} bytes"
             )}

          _, changeset ->
            {:cont, changeset}
        end)
    end
  end
```

# No usage of ok/error... but fun to refactor 😅

```elixir
  @max_prop_key_length Plausible.Props.max_prop_key_length()
  @max_prop_value_length Plausible.Props.max_prop_value_length()
  defp validate_props(changeset) do
    Changeset.get_field(changeset, :props)
    |> Enum.find(props, fn {key, value} ->
      byte_size(key) > @max_prop_key_length or
        byte_size(value) > @max_prop_value_length
    end)
    |> case do
      nil ->
        changeset

      _ ->
         Changeset.add_error(
           changeset,
           :props,
           "keys should have at most #{@max_prop_key_length} bytes and values #{@max_prop_value_length} bytes"
         )
    end
  end
```


