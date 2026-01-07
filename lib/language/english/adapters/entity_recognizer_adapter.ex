defmodule Nasty.Language.English.Adapters.EntityRecognizerAdapter do
  @moduledoc """
  Adapter that bridges the English.EntityRecognizer implementation to the
  generic Semantic.EntityRecognition behaviour.
  """

  @behaviour Nasty.Semantic.EntityRecognition

  alias Nasty.AST.{Document, Sentence}
  alias Nasty.Language.English.EntityRecognizer

  @impl true
  def recognize_document(%Document{} = document, opts \\ []) do
    # Extract entities from all sentences in document
    entities =
      document
      |> Document.all_sentences()
      |> Enum.flat_map(fn sentence ->
        case recognize_sentence(sentence, opts) do
          {:ok, entities} -> entities
          {:error, _} -> []
        end
      end)
      |> Enum.uniq_by(& &1.text)

    {:ok, entities}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @impl true
  def recognize_sentence(%Sentence{} = sentence, opts \\ []) do
    # Extract tokens from sentence and recognize entities
    tokens = extract_tokens_from_sentence(sentence)
    recognize(tokens, opts)
  rescue
    e -> {:error, Exception.message(e)}
  end

  @impl true
  def recognize(tokens, _opts \\ []) do
    # Delegate to existing English implementation
    entities = EntityRecognizer.recognize(tokens)
    {:ok, entities}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @impl true
  def supported_types do
    # Match the actual types returned by English.EntityRecognizer
    [:person, :org, :gpe, :loc, :date, :time, :money, :percent, :misc]
  end

  # Private helper to extract tokens from sentence
  defp extract_tokens_from_sentence(%Sentence{main_clause: clause}) do
    extract_tokens_from_clause(clause)
  end

  defp extract_tokens_from_clause(%{subject: subject, predicate: predicate}) do
    subject_tokens = if subject, do: extract_tokens_from_phrase(subject), else: []
    predicate_tokens = extract_tokens_from_phrase(predicate)
    subject_tokens ++ predicate_tokens
  end

  defp extract_tokens_from_phrase(%{head: head} = phrase) when is_map(phrase) do
    tokens = [head]

    # Add tokens from modifiers, complements, etc.
    additional =
      phrase
      |> Map.get(:modifiers, [])
      |> Enum.flat_map(&extract_tokens_from_node/1)

    tokens ++ additional
  end

  defp extract_tokens_from_phrase(token) when is_map(token), do: [token]
  defp extract_tokens_from_phrase(_), do: []

  defp extract_tokens_from_node(node) when is_list(node),
    do: Enum.flat_map(node, &extract_tokens_from_node/1)

  defp extract_tokens_from_node(node) when is_map(node) and is_map_key(node, :text), do: [node]
  defp extract_tokens_from_node(node) when is_map(node), do: extract_tokens_from_phrase(node)
  defp extract_tokens_from_node(_), do: []
end
