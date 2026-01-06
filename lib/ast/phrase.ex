defmodule Nasty.AST.Phrase do
  @moduledoc """
  Phrase-level AST nodes for syntactic structure.

  Phrases are the building blocks of sentences, grouping tokens into
  functional units (noun phrases, verb phrases, etc.).
  """

  alias Nasty.AST.{Node, Token}

  defprotocol Phrase do
    @moduledoc """
    Base protocol for all phrase types.
    """
    @doc "Returns the span of the phrase"
    def span(phrase)

    @doc "Returns the language of the phrase"
    def language(phrase)

    @doc "Returns the head (main) element of the phrase"
    def head(phrase)
  end
end

defmodule Nasty.AST.NounPhrase do
  @moduledoc """
  Noun Phrase: A phrase headed by a noun.

  Structure: (Determiner) (Modifiers)* Head (PostModifiers)*

  ## Examples
  - "the cat" - determiner + head
  - "the quick brown fox" - determiner + modifiers + head
  - "the cat on the mat" - determiner + head + PP postmodifier
  - "the cat that sat" - determiner + head + relative clause
  """

  alias Nasty.AST.{Node, Token}

  @type t :: %__MODULE__{
          determiner: Token.t() | nil,
          modifiers: [Token.t() | Nasty.AST.AdjectivalPhrase.t()],
          head: Token.t(),
          post_modifiers: [
            Nasty.AST.PrepositionalPhrase.t() | Nasty.AST.Clause.t()
          ],
          entity: Nasty.AST.Semantic.Entity.t() | nil,
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:head, :language, :span]
  defstruct [
    :head,
    :language,
    :span,
    determiner: nil,
    modifiers: [],
    post_modifiers: [],
    entity: nil
  ]

  defimpl Nasty.AST.Phrase.Phrase do
    def span(np), do: np.span
    def language(np), do: np.language
    def head(np), do: np.head
  end
end

defmodule Nasty.AST.VerbPhrase do
  @moduledoc """
  Verb Phrase: A phrase headed by a verb.

  Structure: (Auxiliaries)* MainVerb (Complements)* (Adverbials)*

  ## Examples
  - "ran" - main verb only
  - "is running" - auxiliary + main verb
  - "has been running quickly" - auxiliaries + main verb + adverbial
  - "gave the dog a bone" - verb + indirect object + direct object
  """

  alias Nasty.AST.{Node, Token}

  @type t :: %__MODULE__{
          auxiliaries: [Token.t()],
          head: Token.t(),
          complements: [Nasty.AST.NounPhrase.t() | Nasty.AST.Clause.t()],
          adverbials: [
            Token.t() | Nasty.AST.AdverbialPhrase.t() | Nasty.AST.PrepositionalPhrase.t()
          ],
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:head, :language, :span]
  defstruct [
    :head,
    :language,
    :span,
    auxiliaries: [],
    complements: [],
    adverbials: []
  ]

  defimpl Nasty.AST.Phrase.Phrase do
    def span(vp), do: vp.span
    def language(vp), do: vp.language
    def head(vp), do: vp.head
  end
end

defmodule Nasty.AST.PrepositionalPhrase do
  @moduledoc """
  Prepositional Phrase: A phrase headed by a preposition.

  Structure: Preposition + NounPhrase

  ## Examples
  - "on the mat" - preposition + NP
  - "in the house" - preposition + NP
  - "with great enthusiasm" - preposition + NP
  """

  alias Nasty.AST.{Node, NounPhrase, Token}

  @type t :: %__MODULE__{
          head: Token.t(),
          object: NounPhrase.t(),
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:head, :object, :language, :span]
  defstruct [:head, :object, :language, :span]

  defimpl Nasty.AST.Phrase.Phrase do
    def span(pp), do: pp.span
    def language(pp), do: pp.language
    def head(pp), do: pp.head
  end
end

defmodule Nasty.AST.AdjectivalPhrase do
  @moduledoc """
  Adjectival Phrase: A phrase headed by an adjective.

  Structure: (Intensifier) Adjective (Complement)

  ## Examples
  - "happy" - adjective only
  - "very happy" - intensifier + adjective
  - "happy with the result" - adjective + PP complement
  """

  alias Nasty.AST.{Node, Token}

  @type t :: %__MODULE__{
          intensifier: Token.t() | nil,
          head: Token.t(),
          complement: Nasty.AST.PrepositionalPhrase.t() | nil,
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:head, :language, :span]
  defstruct [
    :head,
    :language,
    :span,
    intensifier: nil,
    complement: nil
  ]

  defimpl Nasty.AST.Phrase.Phrase do
    def span(ap), do: ap.span
    def language(ap), do: ap.language
    def head(ap), do: ap.head
  end
end

defmodule Nasty.AST.AdverbialPhrase do
  @moduledoc """
  Adverbial Phrase: A phrase headed by an adverb.

  Structure: (Intensifier) Adverb

  ## Examples
  - "quickly" - adverb only
  - "very quickly" - intensifier + adverb
  - "rather slowly" - intensifier + adverb
  """

  alias Nasty.AST.{Node, Token}

  @type t :: %__MODULE__{
          intensifier: Token.t() | nil,
          head: Token.t(),
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:head, :language, :span]
  defstruct [
    :head,
    :language,
    :span,
    intensifier: nil
  ]

  defimpl Nasty.AST.Phrase.Phrase do
    def span(ap), do: ap.span
    def language(ap), do: ap.language
    def head(ap), do: ap.head
  end
end
