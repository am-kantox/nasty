defmodule Nasty.AST.Dependency do
  @moduledoc """
  Dependency arc representing a grammatical relation between tokens.

  Dependencies follow the Universal Dependencies (UD) annotation scheme,
  providing a cross-linguistically consistent representation of grammatical structure.

  Reference: https://universaldependencies.org/u/dep/
  """

  alias Nasty.AST.{Node, Token}

  @typedoc """
  Universal Dependencies relation types.

  ## Core arguments
  - `:nsubj` - Nominal subject
  - `:obj` - Object
  - `:iobj` - Indirect object
  - `:csubj` - Clausal subject
  - `:ccomp` - Clausal complement
  - `:xcomp` - Open clausal complement

  ## Non-core dependents
  - `:obl` - Oblique nominal
  - `:vocative` - Vocative
  - `:expl` - Expletive
  - `:dislocated` - Dislocated elements

  ## Nominal dependents
  - `:nmod` - Nominal modifier
  - `:appos` - Appositional modifier
  - `:nummod` - Numeric modifier

  ## Case-marking & function words
  - `:case` - Case marking
  - `:det` - Determiner
  - `:clf` - Classifier

  ## Compounding & MWE
  - `:compound` - Compound
  - `:flat` - Flat multiword expression
  - `:fixed` - Fixed multiword expression

  ## Loose joining relations
  - `:list` - List
  - `:parataxis` - Parataxis

  ## Coordination
  - `:conj` - Conjunct
  - `:cc` - Coordinating conjunction

  ## Modifier words
  - `:amod` - Adjectival modifier
  - `:advmod` - Adverb modifier
  - `:aux` - Auxiliary
  - `:cop` - Copula
  - `:mark` - Marker

  ## Other
  - `:acl` - Clausal modifier of noun (adjectival clause)
  - `:advcl` - Adverbial clause modifier
  - `:discourse` - Discourse element
  - `:punct` - Punctuation
  - `:root` - Root of the sentence
  - `:dep` - Unspecified dependency

  Reference: https://universaldependencies.org/u/dep/
  """
  # Core arguments
  @type relation_type ::
          :nsubj
          | :obj
          | :iobj
          | :csubj
          | :ccomp
          | :xcomp
          # Non-core
          | :obl
          | :vocative
          | :expl
          | :dislocated
          # Nominal
          | :nmod
          | :appos
          | :nummod
          # Function words
          | :case
          | :det
          | :clf
          # Compounding
          | :compound
          | :flat
          | :fixed
          # Loose joining
          | :list
          | :parataxis
          # Coordination
          | :conj
          | :cc
          # Modifiers
          | :amod
          | :advmod
          | :aux
          | :cop
          | :mark
          # Clausal modifiers
          | :acl
          | :advcl
          # Other
          | :discourse
          | :punct
          | :root
          | :dep

  @type t :: %__MODULE__{
          relation: relation_type(),
          head: Token.t(),
          dependent: Token.t(),
          span: Node.span()
        }

  @enforce_keys [:relation, :head, :dependent, :span]
  defstruct [:relation, :head, :dependent, :span]

  @doc """
  Creates a new dependency arc.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)
      iex> head = %Nasty.AST.Token{text: "sat", pos_tag: :verb, language: :en, span: span}
      iex> dep = %Nasty.AST.Token{text: "cat", pos_tag: :noun, language: :en, span: span}
      iex> arc = Nasty.AST.Dependency.new(:nsubj, head, dep, span)
      iex> arc.relation
      :nsubj
  """
  @spec new(relation_type(), Token.t(), Token.t(), Node.span()) :: t()
  def new(relation, head, dependent, span) do
    %__MODULE__{
      relation: relation,
      head: head,
      dependent: dependent,
      span: span
    }
  end

  @doc """
  Checks if relation is a core argument (subject, object, clausal complement).

  ## Examples

      iex> dep = %Nasty.AST.Dependency{relation: :nsubj, ...}
      iex> Nasty.AST.Dependency.core_argument?(dep)
      true
      
      iex> dep = %Nasty.AST.Dependency{relation: :amod, ...}
      iex> Nasty.AST.Dependency.core_argument?(dep)
      false
  """
  @spec core_argument?(t()) :: boolean()
  def core_argument?(%__MODULE__{relation: rel}) do
    rel in [:nsubj, :obj, :iobj, :csubj, :ccomp, :xcomp]
  end

  @doc """
  Checks if relation is a modifier (adjectival, adverbial, nominal).

  ## Examples

      iex> dep = %Nasty.AST.Dependency{relation: :amod, ...}
      iex> Nasty.AST.Dependency.modifier?(dep)
      true
  """
  @spec modifier?(t()) :: boolean()
  def modifier?(%__MODULE__{relation: rel}) do
    rel in [:amod, :advmod, :nmod, :nummod, :acl, :advcl]
  end

  @doc """
  Checks if relation is a function word (determiner, case marker, auxiliary).

  ## Examples

      iex> dep = %Nasty.AST.Dependency{relation: :det, ...}
      iex> Nasty.AST.Dependency.function_word?(dep)
      true
  """
  @spec function_word?(t()) :: boolean()
  def function_word?(%__MODULE__{relation: rel}) do
    rel in [:det, :case, :aux, :cop, :mark, :cc]
  end

  @doc """
  Returns all supported Universal Dependencies relation types.
  """
  @spec relation_types() :: [relation_type()]
  def relation_types do
    [
      # Core
      :nsubj,
      :obj,
      :iobj,
      :csubj,
      :ccomp,
      :xcomp,
      # Non-core
      :obl,
      :vocative,
      :expl,
      :dislocated,
      # Nominal
      :nmod,
      :appos,
      :nummod,
      # Function
      :case,
      :det,
      :clf,
      # Compound
      :compound,
      :flat,
      :fixed,
      # Loose
      :list,
      :parataxis,
      # Coordination
      :conj,
      :cc,
      # Modifiers
      :amod,
      :advmod,
      :aux,
      :cop,
      :mark,
      # Clausal
      :acl,
      :advcl,
      # Other
      :discourse,
      :punct,
      :root,
      :dep
    ]
  end
end
