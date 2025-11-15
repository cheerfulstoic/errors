# Interesting Examples

## TODO

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

The following is a refactor using the `triage` library. Aside from genenrally removing the boilerplate of handling `{:ok, _}` and `{:error, _}` wrappers, this refactor:

* ... removes 52 lines of the original 108 lines code (48%)
* ... removes two functions
* ... makes it clear at a higher level when we're mapping over operations

If we moved to using `Triage.wrap_context` and changed the `FallbackController` to handle the resulting `WrappedError`s, we could also potentially remove some of the error handling here while also adding some useful context to errors which are returned.

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
    |> Triage.then(&compose_transactions/1)
    |> Triage.then(fn composed ->
      noun = Nounable.to_noun(composed)

      Jam.jam(noun)
    end)
    |> Triage.handle(fn
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
    |> Triage.then(&noun_to_transaction/1)
    |> Triage.then(fn transaction ->
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
    |> Triage.handle(fn %{message: err} -> {:cue_failed, err} end)
  end

  @spec noun_to_transaction(Noun.t()) ::
          {:ok, Transaction.t()} | {:error, :noun_not_a_valid_transaction}
  defp noun_to_transaction(noun) do
    Transaction.from_noun(noun)
    |> Triage.handle(fn :error -> :noun_not_a_valid_transaction end)
  end
```
