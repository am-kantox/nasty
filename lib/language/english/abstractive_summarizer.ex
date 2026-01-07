defmodule Nasty.Language.English.AbstractiveSummarizer do
  @moduledoc """
  Template-based abstractive summarization for English.

  Generates new summary sentences by:
  1. Extracting semantic facts (subject-verb-object triples)
  2. Ranking facts by importance (entities, important verbs)
  3. Combining related facts into fluent sentences

  ## Examples

      iex> {:ok, doc} = Nasty.parse("John works at Google. Google develops search technology.", language: :en)
      iex> summary = AbstractiveSummarizer.summarize(doc)
      ["John works at Google and develops search technology."]
  """

  @behaviour Nasty.Operations.Summarization.Abstractive

  alias Nasty.AST.{Document, Sentence}
  alias Nasty.Operations.Summarization.Abstractive

  @impl true
  def extract_facts(%Sentence{} = sentence) do
    # Use the basic fact extraction from the generic module
    Abstractive.extract_basic_facts(sentence)
  end

  @impl true
  def rank_facts(facts, document) do
    # Score each fact and return ranked list
    Enum.map(facts, fn fact ->
      score = Abstractive.score_fact(fact, document)
      {fact, score}
    end)
  end

  @impl true
  def generate_sentence(facts) when is_list(facts) do
    # Use the default sentence generation with some improvements
    case facts do
      [] ->
        ""

      [{subject, verb, nil}] ->
        # No object - simple sentence
        "#{subject} #{verb}."

      [{subject, verb, object}] ->
        # Single fact - simple sentence
        "#{subject} #{verb} #{object}."

      [{subject, verb1, object1}, {subj2, verb2, object2}] when subject == subj2 ->
        # Two facts about same subject - combine with "and"
        "#{subject} #{verb1} #{object1} and #{verb2} #{object2}."

      [{subject, verb1, object1} | rest] ->
        # Multiple facts - list them
        additional =
          rest
          |> Enum.map(fn fact ->
            case fact do
              {^subject, verb, nil} -> verb
              {^subject, verb, object} -> "#{verb} #{object}"
              {_other_subject, _verb, _object} -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> case do
            [] -> ""
            [single] -> " and #{single}"
            multiple -> ", " <> Enum.join(multiple, ", and ")
          end

        "#{subject} #{verb1} #{object1}#{additional}."
    end
  end

  @doc """
  Public API: Generate abstractive summary from document.

  ## Options

  - `:max_facts` - Maximum facts to include (default: 3)
  - `:max_sentences` - Maximum sentences to generate (default: 2)
  - `:combine_related` - Combine facts about same subject (default: true)

  Returns list of generated summary sentences.
  """
  @spec summarize(Document.t(), keyword()) :: [String.t()]
  def summarize(%Document{} = document, opts \\ []) do
    Abstractive.summarize(__MODULE__, document, opts)
  end
end
