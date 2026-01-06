defmodule Nasty.AST.RelativeClause do
  @moduledoc """
  Represents a relative clause that modifies a noun.

  Relative clauses provide additional information about a noun and are typically
  introduced by relative pronouns (who, whom, whose, which, that) or relative
  adverbs (where, when, why).

  ## Examples

  - Restrictive: "The cat **that sits on the mat**"
  - Non-restrictive: "The dog, **which was brown**, ran"
  - With relative adverb: "The place **where we met**"

  ## Fields

  - `:relativizer` - The relative pronoun/adverb introducing the clause
  - `:clause` - The clause structure (subject may be omitted if relativizer is subject)
  - `:type` - `:restrictive` or `:non_restrictive`
  - `:language` - Language code (e.g., `:en`)
  - `:span` - Source text span
  """

  alias Nasty.AST.{Clause, Node, Token}

  @type t :: %__MODULE__{
          relativizer: Token.t(),
          clause: Clause.t(),
          type: :restrictive | :non_restrictive,
          language: atom(),
          span: Node.span()
        }

  @enforce_keys [:relativizer, :clause, :language, :span]
  defstruct [
    :relativizer,
    :clause,
    :language,
    :span,
    type: :restrictive
  ]
end
