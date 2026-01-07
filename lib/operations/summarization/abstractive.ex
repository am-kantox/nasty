defmodule Nasty.Operations.Summarization.Abstractive do
  @moduledoc """
  Template-based abstractive summarization.

  Unlike extractive summarization which selects existing sentences,
  abstractive summarization generates new sentences by:

  1. Extracting key semantic facts (subject-verb-object triples)
  2. Identifying important entities and actions
  3. Generating new sentences using templates

  This is a rule-based approach suitable for pure Elixir implementation.
  For neural abstractive summarization (seq2seq, transformers), external
  models would be required.

  ## Approach

  - Extract semantic facts from sentences
  - Rank facts by importance
  - Generate new sentences from top-ranked facts using templates
  - Combine related facts into coherent summaries

  ## Example

      iex> doc = Nasty.parse("John works at Google. Google is a tech company.", language: :en)
      iex> summary = Abstractive.summarize(impl, doc, max_facts: 2)
      ["John works at Google, a tech company."]
  """

  alias Nasty.AST.{Document, Sentence}

  @doc """
  Callback for extracting semantic facts from a sentence.
  Returns list of {subject, verb, object} triples.
  """
  @callback extract_facts(Sentence.t()) :: [{String.t(), String.t(), String.t()}]

  @doc """
  Callback for ranking facts by importance (optional).
  Receives facts and document context, returns scored facts.
  """
  @callback rank_facts([fact()], Document.t()) :: [{fact(), float()}]

  @doc """
  Callback for generating sentence from facts (optional).
  Receives facts and generates a natural language sentence.
  """
  @callback generate_sentence([fact()]) :: String.t()

  @type fact :: {subject :: String.t(), verb :: String.t(), object :: String.t()}

  @optional_callbacks rank_facts: 2, generate_sentence: 1

  @doc """
  Generates an abstractive summary by extracting and reformulating key facts.

  ## Options

  - `:max_facts` - Maximum number of facts to include (default: 3)
  - `:max_sentences` - Maximum number of generated sentences (default: 2)
  - `:combine_related` - Combine related facts into single sentences (default: true)

  Returns a list of generated summary strings.
  """
  @spec summarize(module(), Document.t(), keyword()) :: [String.t()]
  def summarize(impl, %Document{} = document, opts \\ []) do
    max_facts = Keyword.get(opts, :max_facts, 3)
    max_sentences = Keyword.get(opts, :max_sentences, 2)
    combine_related = Keyword.get(opts, :combine_related, true)

    # Extract all sentences
    sentences = extract_all_sentences(document)

    # Extract facts from all sentences
    all_facts =
      sentences
      |> Enum.flat_map(&impl.extract_facts/1)
      |> Enum.uniq()

    # Rank facts by importance
    ranked_facts =
      if function_exported?(impl, :rank_facts, 2) do
        impl.rank_facts(all_facts, document)
      else
        # Default ranking: all facts equally important
        Enum.map(all_facts, fn fact -> {fact, 1.0} end)
      end

    # Select top facts
    top_facts =
      ranked_facts
      |> Enum.sort_by(fn {_fact, score} -> -score end)
      |> Enum.take(max_facts)
      |> Enum.map(fn {fact, _score} -> fact end)

    # Generate summary sentences
    if combine_related do
      generate_combined_summary(impl, top_facts, max_sentences)
    else
      generate_simple_summary(impl, top_facts, max_sentences)
    end
  end

  @doc """
  Extracts all sentences from a document.
  """
  @spec extract_all_sentences(Document.t()) :: [Sentence.t()]
  def extract_all_sentences(%Document{paragraphs: paragraphs}) do
    paragraphs
    |> Enum.flat_map(fn para -> para.sentences end)
  end

  @doc """
  Generates summary by combining related facts into sentences.
  """
  @spec generate_combined_summary(module(), [fact()], integer()) :: [String.t()]
  def generate_combined_summary(impl, facts, max_sentences) do
    # Group facts by subject
    fact_groups =
      facts
      |> Enum.group_by(fn {subject, _verb, _object} -> subject end)
      |> Map.values()

    # Generate one sentence per group
    fact_groups
    |> Enum.take(max_sentences)
    |> Enum.map(fn group_facts ->
      if function_exported?(impl, :generate_sentence, 1) do
        impl.generate_sentence(group_facts)
      else
        generate_default_sentence(group_facts)
      end
    end)
  end

  @doc """
  Generates simple summary with one fact per sentence.
  """
  @spec generate_simple_summary(module(), [fact()], integer()) :: [String.t()]
  def generate_simple_summary(impl, facts, max_sentences) do
    facts
    |> Enum.take(max_sentences)
    |> Enum.map(fn fact ->
      if function_exported?(impl, :generate_sentence, 1) do
        impl.generate_sentence([fact])
      else
        generate_default_sentence([fact])
      end
    end)
  end

  @doc """
  Default sentence generation using simple templates.
  """
  @spec generate_default_sentence([fact()]) :: String.t()
  def generate_default_sentence([{subject, verb, object}]) do
    "#{subject} #{verb} #{object}."
  end

  def generate_default_sentence([{subject, verb1, object1} | rest]) do
    # Combine multiple facts about same subject
    additional_facts =
      rest
      |> Enum.map(fn {_subject, verb, object} -> "#{verb} #{object}" end)
      |> Enum.join(" and ")

    if additional_facts == "" do
      "#{subject} #{verb1} #{object1}."
    else
      "#{subject} #{verb1} #{object1} and #{additional_facts}."
    end
  end

  @doc """
  Extracts subject-verb-object triples from a sentence using basic parsing.

  This is a simple heuristic-based extraction. For better results,
  language implementations should override with more sophisticated parsing.
  """
  @spec extract_basic_facts(Sentence.t()) :: [fact()]
  def extract_basic_facts(%Sentence{main_clause: clause}) do
    extract_facts_from_clause(clause)
  end

  # Extract facts from clause structure
  defp extract_facts_from_clause(%{subject: subject, predicate: predicate})
       when not is_nil(subject) do
    subject_text = extract_text_from_phrase(subject)
    {verb, object_text} = extract_verb_and_object(predicate)

    if subject_text && verb && object_text do
      [{subject_text, verb, object_text}]
    else
      []
    end
  end

  defp extract_facts_from_clause(_), do: []

  # Extract text from noun phrase
  defp extract_text_from_phrase(%{head: head, modifiers: mods}) do
    texts = [head.text | Enum.map(mods, & &1.text)]
    Enum.join(texts, " ")
  end

  defp extract_text_from_phrase(%{head: head}), do: head.text
  defp extract_text_from_phrase(_), do: nil

  # Extract verb and object from verb phrase
  defp extract_verb_and_object(%{head: head, complements: complements})
       when is_list(complements) do
    verb = head.text

    object =
      complements
      |> Enum.map(&extract_text_from_phrase/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    {verb, if(object != "", do: object, else: nil)}
  end

  defp extract_verb_and_object(%{head: head}) do
    {head.text, nil}
  end

  defp extract_verb_and_object(_), do: {nil, nil}

  @doc """
  Scores facts based on entity presence and verb importance.
  """
  @spec score_fact(fact(), Document.t()) :: float()
  def score_fact({subject, verb, object}, _document) do
    score = 0.5

    # Boost score if subject is capitalized (likely entity)
    score = if capitalized?(subject), do: score + 0.3, else: score

    # Boost score if object is capitalized (likely entity)
    score = if object && capitalized?(object), do: score + 0.2, else: score

    # Boost score for important verbs
    important_verbs = ~w(is was are were creates founded develops invented discovered)

    score =
      if verb in important_verbs, do: score + 0.2, else: score

    score
  end

  defp capitalized?(text) when is_binary(text) do
    first = String.first(text)
    first == String.upcase(first) && first =~ ~r/[A-Z]/
  end

  defp capitalized?(_), do: false
end
