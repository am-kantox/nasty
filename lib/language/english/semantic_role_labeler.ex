defmodule Nasty.Language.English.SemanticRoleLabeler do
  @moduledoc """
  Semantic Role Labeling (SRL) for English.

  Thin wrapper around generic SRL modules with English-specific configuration.
  Extracts predicate-argument structure from sentences by mapping
  syntactic dependencies to semantic roles (Agent, Patient, Theme, etc.).

  ## Examples

      iex> alias Nasty.Language.English.{Tokenizer, POSTagger, SentenceParser}
      iex> {:ok, tokens} = Tokenizer.tokenize("John gave Mary a book.")
      iex> {:ok, tagged} = POSTagger.tag_pos(tokens)
      iex> {:ok, analyzed} = Morphology.analyze(tagged)
      iex> {:ok, sentences} = SentenceParser.parse_sentences(analyzed)
      iex> sentence = List.first(sentences)
      iex> {:ok, frames} = SemanticRoleLabeler.label(sentence)
      iex> frame = List.first(frames)
      iex> frame.predicate.text
      "gave"
      iex> Enum.map(frame.roles, & &1.type)
      [:agent, :patient, :recipient]
  """

  alias Nasty.AST.{Clause, Sentence}
  alias Nasty.AST.Semantic.Frame
  alias Nasty.Language.English.SRLConfig
  alias Nasty.Semantic.SRL.Labeler

  @doc """
  Labels semantic roles for all predicates in a sentence.

  Returns a list of semantic frames, one per predicate (main verb).

  ## Examples

      iex> {:ok, frames} = SemanticRoleLabeler.label(sentence)
      iex> is_list(frames)
      true
  """
  @spec label(Sentence.t(), keyword()) :: {:ok, [Frame.t()]} | {:error, term()}
  def label(%Sentence{} = sentence, opts \\ []) do
    Labeler.label(sentence, SRLConfig.config(), opts)
  end

  @doc """
  Labels semantic roles for a single clause.

  Delegates to generic labeler with English configuration.
  """
  @spec label_clause(Clause.t()) :: [Frame.t()]
  def label_clause(%Clause{} = clause) do
    Labeler.label_clause(clause, SRLConfig.config())
  end
end
