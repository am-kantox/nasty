defmodule Nasty.AST.Sentence do
  @moduledoc """
  Sentence node representing a complete grammatical unit.

  A sentence consists of one or more clauses that form a complete thought.
  Sentences are classified by their function (declarative, interrogative, etc.)
  and structure (simple, compound, complex, compound-complex).
  """

  alias Nasty.AST.{Clause, Node}

  @typedoc """
  Sentence function classification.

  - `:declarative` - Makes a statement ("The cat sat.")
  - `:interrogative` - Asks a question ("Did the cat sit?")
  - `:imperative` - Gives a command ("Sit!")
  - `:exclamative` - Expresses strong emotion ("What a cat!")
  """
  @type sentence_function :: :declarative | :interrogative | :imperative | :exclamative

  @typedoc """
  Sentence structure classification.

  - `:simple` - One independent clause
  - `:compound` - Multiple independent clauses
  - `:complex` - One independent + dependent clause(s)
  - `:compound_complex` - Multiple independent + dependent clause(s)
  - `:fragment` - Incomplete sentence (missing subject or predicate)
  """
  @type sentence_structure :: :simple | :compound | :complex | :compound_complex | :fragment

  @type t :: %__MODULE__{
          function: sentence_function(),
          structure: sentence_structure(),
          main_clause: Clause.t(),
          additional_clauses: [Clause.t()],
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:function, :structure, :main_clause, :language, :span]
  defstruct [
    :function,
    :structure,
    :main_clause,
    :language,
    :span,
    additional_clauses: []
  ]

  @doc """
  Creates a new sentence.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 15}, 15)
      iex> clause = %Nasty.AST.Clause{type: :independent, predicate: vp, language: :en, span: span}
      iex> sentence = Nasty.AST.Sentence.new(:declarative, :simple, clause, :en, span)
      iex> sentence.function
      :declarative
      iex> sentence.structure
      :simple
  """
  @spec new(
          sentence_function(),
          sentence_structure(),
          Clause.t(),
          Node.language(),
          Node.span(),
          keyword()
        ) ::
          t()
  def new(function, structure, main_clause, language, span, opts \\ []) do
    %__MODULE__{
      function: function,
      structure: structure,
      main_clause: main_clause,
      language: language,
      span: span,
      additional_clauses: Keyword.get(opts, :additional_clauses, [])
    }
  end

  @doc """
  Infers sentence structure from clauses.

  ## Examples

      iex> main = %Nasty.AST.Clause{type: :independent, ...}
      iex> Nasty.AST.Sentence.infer_structure(main, [])
      :simple
      
      iex> main = %Nasty.AST.Clause{type: :independent, ...}
      iex> sub = %Nasty.AST.Clause{type: :subordinate, ...}
      iex> Nasty.AST.Sentence.infer_structure(main, [sub])
      :complex
  """
  @spec infer_structure(Clause.t(), [Clause.t()]) :: sentence_structure()
  def infer_structure(main_clause, additional_clauses) do
    independent_count =
      Enum.count([main_clause | additional_clauses], &Clause.independent?/1)

    dependent_count =
      Enum.count([main_clause | additional_clauses], &Clause.dependent?/1)

    cond do
      independent_count == 1 and dependent_count == 0 ->
        :simple

      independent_count > 1 and dependent_count == 0 ->
        :compound

      independent_count == 1 and dependent_count > 0 ->
        :complex

      independent_count > 1 and dependent_count > 0 ->
        :compound_complex

      true ->
        :fragment
    end
  end

  @doc """
  Returns all clauses in the sentence.

  ## Examples

      iex> sentence = %Nasty.AST.Sentence{main_clause: main, additional_clauses: [sub1, sub2], ...}
      iex> Nasty.AST.Sentence.all_clauses(sentence)
      [main, sub1, sub2]
  """
  @spec all_clauses(t()) :: [Clause.t()]
  def all_clauses(%__MODULE__{main_clause: main, additional_clauses: additional}) do
    [main | additional]
  end

  @doc """
  Checks if sentence is a question.

  ## Examples

      iex> sentence = %Nasty.AST.Sentence{function: :interrogative, ...}
      iex> Nasty.AST.Sentence.question?(sentence)
      true
  """
  @spec question?(t()) :: boolean()
  def question?(%__MODULE__{function: :interrogative}), do: true
  def question?(_), do: false

  @doc """
  Checks if sentence is a command.

  ## Examples

      iex> sentence = %Nasty.AST.Sentence{function: :imperative, ...}
      iex> Nasty.AST.Sentence.command?(sentence)
      true
  """
  @spec command?(t()) :: boolean()
  def command?(%__MODULE__{function: :imperative}), do: true
  def command?(_), do: false

  @doc """
  Checks if sentence is complete (not a fragment).

  ## Examples

      iex> sentence = %Nasty.AST.Sentence{structure: :simple, ...}
      iex> Nasty.AST.Sentence.complete?(sentence)
      true
  """
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{structure: :fragment}), do: false
  def complete?(_), do: true
end
