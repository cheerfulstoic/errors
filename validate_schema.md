
<https://github.com/oban-bg/oban/blob/0dee4e1092eb88e7f2ebe52a3d71c6f621475e12/lib/oban/validation.ex#L51>

```elixir
  def validate_schema(opts, schema) when is_list(schema) do
    Enum.reduce_while(opts, :ok, fn {key, val}, acc ->
      case Keyword.fetch(schema, key) do
        {:ok, type} ->
          case validate_type(type, key, val) do
            :ok -> {:cont, acc}
            error -> {:halt, error}
          end

        :error ->
          {:halt, unknown_error(key, Keyword.keys(schema))}
      end
    end)
  end
```

```elixir
  def validate_schema(opts, schema) when is_list(schema) do
    Enum.reduce_while(opts, :ok, fn {key, val}, acc ->
      with {:ok, type} <- Keyword.fetch(schema, key),
           :ok <- validate_type(type, key, val) do
        {:cont, acc}
      else
        :error ->
          {:halt, unknown_error(key, Keyword.keys(schema))}

        error -> {:halt, error}
      end
    end)
  end
```

```elixir
  def validate_schema(opts, schema) when is_list(schema) do
    case Enum.find(opts, fn {key, _} -> !Keyword.has_key?(schema, key) end)
      {key, _} -> 
        unknown_error(key, Keyword.keys(schema))
    
      nil ->
        Enum.find_value(opts, fn {key, val} ->
          with :ok <- validate_type(schema[key], key, val), do: nil
        end)
    end
  end
```

In this example, all keys are checked for validity first.

```elixir
  def validate_schema(opts, schema) when is_list(schema) do
    Enum.reduce_while(opts, :ok, fn {key, val}, acc ->
      case validate_schema_key(schema, key, val) do
        :ok -> {:cont, acc}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_schema_key(schema, key, val) do
    if Keyword.has_key?(schema, key) do
      validate_type(schema[key], key, val)
    else
      unknown_error(key, Keyword.keys(schema))
    end
  end
```

```elixir
  def validate_schema(opts, schema) when is_list(schema) do
    Triage.find_error(opts, fn {key, val} -> validate_schema_key(schema, key, val) end)
  end
```
