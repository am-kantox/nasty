defmodule Nasty.Language.Spanish.SemanticRoleLabeler do
  @moduledoc """
  Labels semantic roles (who did what to whom) in Spanish sentences.

  Identifies predicate-argument structures and assigns semantic roles:
  - Agent (A0): who performs the action
  - Patient/Theme (A1): what is affected
  - Instrument (A2): with what
  - Beneficiary (A3): for whom
  - Adjuncts: where, when, why, how

  ## Spanish-Specific Features

  - Flexible word order (SVO, VSO, VOS)
  - Pro-drop subjects (null agent)
  - Clitic pronouns encoding roles (lo, la, le, les)
  - Reflexive constructions (se)
  - Prepositional role markers (a, de, en, con, por, para)

  ## Example

      iex> sentence = parse("María le dio un libro a Juan ayer")
      iex> roles = SemanticRoleLabeler.label(sentence)
      %{
        predicate: "dio",
        arguments: [
          %{role: :agent, text: "María"},
          %{role: :theme, text: "un libro"},
          %{role: :recipient, text: "a Juan"},
          %{role: :time, text: "ayer"}
        ]
      }
  """

  alias Nasty.AST.Sentence
  alias Nasty.Language.Spanish.SRLConfig
  alias Nasty.Semantic.SRL.Labeler

  @doc """
  Labels semantic roles in a Spanish sentence.

  Returns a map with predicate and its semantic arguments.
  """
  @spec label(Sentence.t()) :: map()
  def label(%Sentence{language: :es} = sentence) do
    config = SRLConfig.get()
    Labeler.label(sentence, config)
  end

  def label(%Sentence{language: lang}) do
    raise ArgumentError,
          "Spanish SRL labeler called with #{lang} sentence. Use language-specific labeler."
  end
end
