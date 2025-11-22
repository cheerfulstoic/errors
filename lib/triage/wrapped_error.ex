defmodule Triage.WrappedError do
  @moduledoc """
  Exception struct which is returned in `{:error, _}` tuples when
  the `wrap_context` module is used.

  Contains
   * context string
   * context metadata
   * an original error result (could be within nested `WrappedError`s)


  These things help make it clearer where an error is coming from.

  Works well with the `log` and `user_message` functions.
  """

  alias Triage.Results
  alias Triage.Stacktrace

  @type t() :: %__MODULE__{}

  @enforce_keys [:result]
  defexception [:result, :context, :stacktrace, :metadata, :message]

  # Offer `new/3` as a way to create `WrappedErrors` so that the `message` is set
  # but also create `message/1` callback in case an exception is created manually
  # See: https://hexdocs.pm/elixir/Exception.html#c:message/1

  def new(result, context, stacktrace, metadata \\ %{})
      when is_binary(context) or is_nil(context) do
    if !(result == :error || (is_tuple(result) && elem(result, 0) == :error)) do
      raise ArgumentError, "Triage wrap either :error or {:error, ...}, got: #{inspect(result)}"
    end

    exception =
      %__MODULE__{
        result: result,
        context: context,
        stacktrace: stacktrace,
        metadata: Map.new(metadata)
      }

    %{exception | message: message(exception)}
  end

  def new_raised(exception, func, stacktrace)
      when is_exception(exception) and is_function(func) do
    exception =
      %__MODULE__{
        # If `result` isn't :ok/:error/{:ok, _}/{:error, _} then it was a raised exception
        result: exception,
        context: func,
        stacktrace: stacktrace,
        metadata: %{}
      }

    %{exception | message: message(exception)}
  end

  def message(%__MODULE__{} = error) when is_binary(error.context) or is_nil(error.context) do
    errors = unwrap(error)

    context_string =
      errors
      |> Enum.map_join("\n", fn error ->
        parts_string =
          [format_line(error), context_desc(error.context), format_metadata(error)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" ")

        "    [CONTEXT] #{parts_string}"
      end)

    message = Results.details(List.last(errors).result).message

    "#{message}\n#{context_string}"
  end

  def message(%__MODULE__{} = error) when is_function(error.context) do
    errors = unwrap(error)

    context_string =
      errors
      |> Enum.map_join("\n", fn error ->
        context_desc =
          if is_function(error.context) do
            function_info = Function.info(error.context)

            "#{inspect(function_info[:module])}.#{function_info[:name]}/1"
          else
            error.context
          end

        parts_string =
          [format_line(error), context_desc, format_metadata(error)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" ")

        "    [CONTEXT] #{parts_string}"
      end)

    message = Results.details(List.last(errors).result).message

    "#{message}\n#{context_string}"
  end

  def context_desc(context) do
    cond do
      is_function(context) ->
        function_info = Function.info(context)

        "#{inspect(function_info[:module])}.#{function_info[:name]}/1"

      is_binary(context) ->
        context

      is_nil(context) ->
        nil
    end
  end

  def unwrap(%__MODULE__{result: {:error, %__MODULE__{} = nested_error}} = error) do
    nested_errors = unwrap(nested_error)

    [error | nested_errors]
  end

  def unwrap(%__MODULE__{} = error) do
    [error]
  end

  defp format_line(error) do
    entry =
      error.stacktrace
      |> Stacktrace.most_relevant_entry()

    if entry do
      if line = Stacktrace.format_file_line(entry) do
        "#{line}:"
      end
    end
  end

  defp format_metadata(error) do
    if map_size(error.metadata) > 0 do
      inspect(error.metadata, custom_options: [sort_maps: true])
    end
  end
end

if Code.ensure_loaded?(JSON.Encoder) do
  defimpl JSON.Encoder, for: Triage.WrappedError do
    def encode(error, encoder) do
      errors = Triage.WrappedError.unwrap(error)

      message = Triage.Results.details(List.last(errors).result).message

      encoder.(%{
        message: message,
        contexts: Enum.map(errors, &%{label: &1.context, metadata: &1.metadata})
      })
    end
  end
end

# if Code.ensure_loaded?(Jason.Encoder) do
defimpl Jason.Encoder, for: Triage.WrappedError do
  def encode(error, opts) do
    errors = Triage.WrappedError.unwrap(error)

    message = Triage.Results.details(List.last(errors).result).message

    Jason.Encode.map(
      %{
        message: message,
        contexts: Enum.map(errors, &%{label: &1.context, metadata: &1.metadata})
      },
      opts
    )
  end
end

# end

defimpl Inspect, for: Triage.WrappedError do
  import Inspect.Algebra

  # In Elixir 1.19+, Inspect protocol can return {doc, opts} to pass through options
  # In Elixir < 1.19, it must return only the document
  if Version.match?(System.version(), ">= 1.19.0") do
    def inspect(wrapped_error, opts), do: {build_doc(wrapped_error), opts}
  else
    def inspect(wrapped_error, _opts), do: build_doc(wrapped_error)
  end

  defp build_doc(wrapped_error) do
    errors = Triage.WrappedError.unwrap(wrapped_error)

    contexts_doc =
      errors
      |> Enum.map(&(Triage.WrappedError.context_desc(&1.context) || inspect(&1.metadata)))
      |> Enum.intersperse(" => ")
      |> concat()

    message = Triage.Results.details(List.last(errors).result).message

    concat(["Triage.WrappedError<<", contexts_doc, " | ", message, ">>"])
  end
end
