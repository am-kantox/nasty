defmodule Nasty.AST.Clause do
  @moduledoc """
  Clause node representing a subject-predicate structure.

  A clause is a grammatical unit containing a subject and a predicate (verb phrase).
  Clauses can be independent (main clauses) or dependent (subordinate clauses).
  """

  alias Nasty.AST.{Node, NounPhrase, VerbPhrase}

  @typedoc """
  Clause type classification.

  - `:independent` - Can stand alone as a sentence (main clause)
  - `:subordinate` - Dependent on another clause (adverbial, nominal, relative)
  - `:relative` - Modifies a noun (relative clause)
  - `:complement` - Completes the meaning of another clause
  """
  @type clause_type :: :independent | :subordinate | :relative | :complement

  @type t :: %__MODULE__{
          type: clause_type(),
          subject: NounPhrase.t() | nil,
          predicate: VerbPhrase.t(),
          subordinator: Nasty.AST.Token.t() | nil,
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:type, :predicate, :language, :span]
  defstruct [
    :type,
    :predicate,
    :language,
    :span,
    subject: nil,
    subordinator: nil
  ]

  @doc """
  Creates a new clause.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)
      iex> vp = %Nasty.AST.VerbPhrase{head: token, language: :en, span: span}
      iex> clause = Nasty.AST.Clause.new(:independent, vp, :en, span)
      iex> clause.type
      :independent
  """
  @spec new(clause_type(), VerbPhrase.t(), Node.language(), Node.span(), keyword()) :: t()
  def new(type, predicate, language, span, opts \\ []) do
    %__MODULE__{
      type: type,
      predicate: predicate,
      language: language,
      span: span,
      subject: Keyword.get(opts, :subject),
      subordinator: Keyword.get(opts, :subordinator)
    }
  end

  @doc """
  Checks if a clause is independent (can stand alone).

  ## Examples

      iex> clause = %Nasty.AST.Clause{type: :independent, predicate: vp, language: :en, span: span}
      iex> Nasty.AST.Clause.independent?(clause)
      true
  """
  @spec independent?(t()) :: boolean()
  def independent?(%__MODULE__{type: :independent}), do: true
  def independent?(_), do: false

  @doc """
  Checks if a clause is dependent (requires main clause).

  ## Examples

      iex> clause = %Nasty.AST.Clause{type: :subordinate, predicate: vp, language: :en, span: span}
      iex> Nasty.AST.Clause.dependent?(clause)
      true
  """
  @spec dependent?(t()) :: boolean()
  def dependent?(%__MODULE__{type: type}) when type != :independent, do: true
  def dependent?(_), do: false
end
