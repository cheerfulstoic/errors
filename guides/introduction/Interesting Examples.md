# Interesting Examples

## A single case statement

[Source](https://github.com/b310-digital/mindwendel/blob/master/lib/mindwendel/services/chat_completions/chat_completions_service_impl.ex#L282-L301) from the mindwedel project.

This code is part of a larger function which makes an LLM request:

```elixir
case ChatCompletions.create(openai_client, chat_completion) do
  {:ok, response} when is_map(response) ->
    {:ok, response}

  {:error, %OpenAIError{status_code: status, message: message} = error} ->
    Logger.error("""
    OpenAI API error:
    Status: #{status}
    Message: #{message || "No message"}
    Full error: #{inspect(error)}
    Provider: #{ai_config[:provider]}
    Model: #{ai_config[:model]}
    """)

    {:error, :llm_request_failed}

  {:error, error} ->
    Logger.error("Unexpected OpenAI API error: #{inspect(error)}")

    {:error, :llm_request_failed}
end
```

* Since there is just one `:ok` pattern, we can simplify it with a single `then!` call.
* While the `wrap_context` won't output the same log exactly, it will provide metadata for either `:error` case
* Since we always return `:llm_request_failed` for errors, this can be a single `error_then`

Since the purpose of returning `:llm_request_failed` is probably to help locate the error when there's a failure, we could even skip the `error_then` entirely and error_then the `WrappedError` higher up which will have information about where the error came from.

```elixir
ChatCompletions.create(openai_client, chat_completion)
|> Triage.then!(fn response when is_map(response) -> response end)
|> Triage.wrap_context(
  status: status,
  message: message,
  provider: ai_config[:provider],
  model: ai_config[:model]
)
|> Triage.log()
|> Triage.error_then(fn _ -> :llm_request_failed end)
```

## Two functions, two cases

[Source](https://github.com/anoma/anoma/blob/base/apps/anoma_client/lib/client/transactions/transactions.ex#L94-L116) from the anoma project.

```elixir
  def store_file(filename, file_path, content_type, s3_client \\ storage_provider()) do
    case File.read(file_path) do
      {:ok, file} ->
        case Vault.encrypt(file) do
          {:ok, encrypted_file} ->
            store_encrypted_file(filename, encrypted_file, content_type, s3_client)

          {:error, error_message} ->
            {:error, "Issue while encrypting file: #{inspect(error_message)}"}
        end

      {:error, reason} ->
        Logger.error("Failed to read file #{file_path}: #{inspect(reason)}")
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp store_encrypted_file(filename, encrypted_file, content_type, s3_client) do
    encrypted_file_path = upload_path(filename)

    case s3_client.put_object(
           bucket_name(),
           encrypted_file_path,
           encrypted_file,
           %{
             content_type: content_type
           }
         ) do
      {:ok, _headers} ->
        {:ok, encrypted_file_path}

      {:error, {error_type, http_status_code, response}} ->
        Logger.error(
          "Error storing file in bucket: #{filename} Type: #{content_type}. Error type: #{error_type} Response code: #{http_status_code} Response Body: #{response.body}"
        )

        {:error, "Issue while storing file."}
    end
  end
```

This allows us to reduce 39 lines down to 20. Also, since `store_encrypted_file` is only used inside of `store_file`, so collapsing it's logic allows us to combine it all into `store_file`.

If we use `Triage.log` just after `File.read` we log just those errors like the original version, but putting it at the end lets us capture everything. The two `wrap_context` calls also allow us to isolate errors when they happen, giving relevant metadata for logging depending on the location.

```elixir
  def store_file(filename, file_path, content_type, s3_client \\ storage_provider()) do
    File.read(file_path)
    |> Triage.then!(&Vault.encrypt/1)
    |> Triage.then!(fn encrypted_file ->
      encrypted_file_path = upload_path(filename)

      s3_client.put_object(
        bucket_name(),
        encrypted_file_path,
        encrypted_file,
        %{content_type: content_type}
      )
      |> Triage.wrap_context("Putting to S3", filename: filename)
      |> Triage.then!(fn _ -> encrypted_file_path end)
    end)
    |> Triage.wrap_context(
      "storing encrypted file",
      filename: filename, file_path: file_path, content_type: content_type
    )
    |> Triage.log()
  end
```

## Large and complex example

[Source](https://github.com/anoma/anoma/blob/base/apps/anoma_client/lib/client/transactions/transactions.ex#L94-L116) from the anoma project.

`@doc` lines removed for brevity

```elixir
  @spec compose([binary()]) ::
          {:ok, binary()}
          | {:error, :invalid_input, term()}
          | {:error, :noun_not_a_valid_transaction}
          | {:error, :not_enough_transactions}
  def compose(transactions) do
    # fetch the jammed intents from the request
    with {:ok, nouns} <- cue_transactions(transactions),
         {:ok, transactions} <- nouns_to_transactions(nouns),
         {:ok, composed} <- compose_transactions(transactions),
         noun <- Nounable.to_noun(composed),
         jammed <- Jam.jam(noun) do
      {:ok, jammed}
    else
      {:error, :cue_failed, err} ->
        {:error, :invalid_input, err}

      {:error, :noun_not_a_valid_transaction} ->
        {:error, :noun_not_a_valid_transaction}

      {:error, :not_enough_transactions} ->
        {:error, :not_enough_transactions}
    end
  end

  @spec verify(binary()) ::
          {:ok, boolean()}
          | {:error, :noun_not_a_valid_transaction | :verify_failed}
          | {:error, :cue_failed, term()}
  def verify(transaction) do
    with {:ok, noun} <- cue_transaction(transaction),
         {:ok, transaction} <- noun_to_transaction(noun),
         valid? when is_boolean(valid?) <- Transaction.verify(transaction) do
      {:ok, valid?}
    else
      {:error, :cue_failed, err} ->
        {:error, :cue_failed, err}

      {:error, :noun_not_a_valid_transaction} ->
        {:error, :noun_not_a_valid_transaction}
    end
  end

  @spec cue_transactions([binary()]) ::
        {:ok, [Noun.t()]} | {:error, :cue_failed, term()}
  defp cue_transactions(transactions) do
    Enum.reduce_while(transactions, [], fn tx, acc ->
      case cue_transaction(tx) do
        {:ok, noun} ->
          {:cont, [noun | acc]}

        {:error, :cue_failed, err} ->
          {:halt, {:error, :cue_failed, err}}
      end
    end)
    |> case do
      {:error, :cue_failed, err} ->
        {:error, :cue_failed, err}

      txs ->
        {:ok, txs}
    end
  end

  @spec cue_transaction(binary()) ::
        {:ok, Noun.t()} | {:error, :cue_failed, term()}
  defp cue_transaction(transaction) do
    case Jam.cue(transaction) do
      {:ok, noun} ->
        {:ok, noun}

      {:error, %{message: err}} ->
        {:error, :cue_failed, err}
    end
  end

  @spec nouns_to_transactions([Noun.t()]) ::
          {:ok, [Transaction.t()]} | {:error, :noun_not_a_valid_transaction}
  defp nouns_to_transactions(nouns) do
    Enum.reduce_while(nouns, [], fn tx, acc ->
      case noun_to_transaction(tx) do
        {:ok, transaction} ->
          {:cont, [transaction | acc]}

        {:error, :noun_not_a_valid_transaction} ->
          {:halt, {:error, :noun_not_a_valid_transaction}}
      end
    end)
    |> case do
      {:error, :noun_not_a_valid_transaction} ->
        {:error, :noun_not_a_valid_transaction}

      txs ->
        {:ok, txs}
    end
  end

  @spec noun_to_transaction(Noun.t()) ::
          {:ok, Transaction.t()} | {:error, :noun_not_a_valid_transaction}
  defp noun_to_transaction(noun) do
    case Transaction.from_noun(noun) do
      {:ok, transaction} ->
        {:ok, transaction}

      :error ->
        {:error, :noun_not_a_valid_transaction}
    end
  end
```

Aside from generally removing the boilerplate of handling `{:ok, _}` and `{:error, _}` wrappers, this refactor:

* ... removes 52 lines of the original 108 lines code (48%)
* ... removes two functions
* ... makes it clear at a higher level when we're mapping over operations

If we moved to using `Triage.wrap_context` and changed the `FallbackController` to error_then the resulting `WrappedError`s, we could also potentially remove some of the error handling here while also adding some useful context to errors which are returned.

```elixir
  @spec compose([binary()]) ::
          {:ok, binary()}
          | {:error, :invalid_input, term()}
          | {:error, :noun_not_a_valid_transaction}
          | {:error, :not_enough_transactions}
  def compose(transactions) do
    # fetch the jammed intents from the request
    transactions
    # Ordered doesn't matter for these two lines because the transactions
    # are going to be composed so while this will produce the reverse
    # of the original, it should be fine
    |> Triage.map_if(&cue_transaction/1)
    |> Triage.map_if(&noun_to_transaction/1)
    |> Triage.then!(&compose_transactions/1)
    |> Triage.then!(fn composed ->
      composed
      |> Nounable.to_noun()
      |> Jam.jam()
    end)
    |> Triage.error_then(fn
      {:cue_failed, err} ->
        {:invalid_input, err}

      :noun_not_a_valid_transaction ->
        :noun_not_a_valid_transaction

      :not_enough_transactions ->
        :not_enough_transactions
    end)
  end

  @spec verify(binary()) ::
          {:ok, boolean()}
          | {:error, :noun_not_a_valid_transaction | :verify_failed}
          | {:error, :cue_failed, term()}
  def verify(transaction) do
    cue_transaction(transaction)
    |> Triage.then!(&noun_to_transaction/1)
    |> Triage.then!(fn transaction ->
      # will raise a `MatchError` when not a boolean
      # should be basically the same result as the `WithClauseError`
      # which would have been raised before
      case Transaction.verify(transaction) do
        valid? when is_boolean(valid?) ->
          valid?
      end
    end)
  end

  @spec cue_transaction(binary()) ::
        {:ok, Noun.t()} | {:error, :cue_failed, term()}
  defp cue_transaction(transaction) do
    Jam.cue(transaction)
    |> Triage.error_then(fn %{message: err} -> {:cue_failed, err} end)
  end

  @spec noun_to_transaction(Noun.t()) ::
          {:ok, Transaction.t()} | {:error, :noun_not_a_valid_transaction}
  defp noun_to_transaction(noun) do
    Transaction.from_noun(noun)
    |> Triage.error_then(fn :error -> :noun_not_a_valid_transaction end)
  end
```
