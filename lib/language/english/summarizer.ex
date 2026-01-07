defmodule Nasty.Language.English.Summarizer do
  @moduledoc """
  Extractive text summarization for English.

  This module provides English-specific configuration for the generic
  extractive summarization algorithm. It implements the callbacks required
  by `Nasty.Operations.Summarization.Extractive` and delegates the actual
  summarization logic to that generic module.

  ## Examples

      iex> document = parse("The cat sat on the mat. The dog ran in the park. ...")
      iex> summary = Summarizer.summarize(document, ratio: 0.3)
      [%Sentence{}, ...]

      iex> summary = Summarizer.summarize(document, max_sentences: 3, method: :mmr)
      [%Sentence{}, ...]
  """

  @behaviour Nasty.Operations.Summarization.Extractive

  alias Nasty.AST.{Document, Sentence}
  alias Nasty.Language.English.EntityRecognizer
  alias Nasty.Operations.Summarization.Extractive

  # Discourse markers that signal important content
  @discourse_markers ~w(
    conclusion summary finally therefore thus hence consequently
    important importantly significant notably crucially essential critical
    indeed fact actually certainly definitely clearly obviously
    however nevertheless nonetheless although despite though but yet
  )

  # Stop words to exclude from TF calculation
  @stop_words ~w(
    a an the this that these those
    is are was were be been being
    have has had having
    do does did doing
    will would shall should may might can could must
    i me my mine you your yours he him his she her hers it its
    we us our ours they them their theirs
    in on at by for with from to of about
    and or but nor
  )

  # Callbacks for Extractive behaviour

  @impl true
  def stop_words, do: @stop_words

  @impl true
  def discourse_markers, do: @discourse_markers

  @impl true
  def entity_recognizer, do: EntityRecognizer

  @impl true
  def extract_tokens(sentence), do: extract_tokens_from_sentence(sentence)

  @doc """
  Summarizes a document by extracting important sentences.

  ## Options

  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum number of sentences in summary
  - `:min_sentence_length` - Minimum sentence length (in tokens)
  - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)
  - `:mmr_lambda` - MMR diversity parameter, 0-1 (default: 0.5)

  Returns a list of selected sentences in document order.
  """
  @spec summarize(Document.t(), keyword()) :: [Sentence.t()]
  def summarize(%Document{} = document, opts \\ []) do
    # Delegate to generic extractive algorithm
    Extractive.summarize(__MODULE__, document, opts)
  end

  # Private helper: extract tokens from sentence (kept for backward compat)
  defp extract_tokens_from_sentence(%Sentence{
         main_clause: clause,
         additional_clauses: additional
       }) do
    main_tokens = extract_tokens_from_clause(clause)
    additional_tokens = Enum.flat_map(additional, &extract_tokens_from_clause/1)
    main_tokens ++ additional_tokens
  end

  defp extract_tokens_from_clause(%{subject: subj, predicate: pred}) do
    subj_tokens = if subj, do: extract_tokens_from_phrase(subj), else: []
    pred_tokens = extract_tokens_from_phrase(pred)
    subj_tokens ++ pred_tokens
  end

  defp extract_tokens_from_phrase(%{
         head: head,
         determiner: det,
         modifiers: mods,
         post_modifiers: _post
       }) do
    tokens = [head | mods]
    if det, do: [det | tokens], else: tokens
  end

  defp extract_tokens_from_phrase(%{head: head, auxiliaries: aux, complements: _comps}) do
    [head | aux]
  end

  defp extract_tokens_from_phrase(%{head: head}) do
    [head]
  end

  defp extract_tokens_from_phrase(_), do: []
end
