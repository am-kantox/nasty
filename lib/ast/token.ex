defmodule Nasty.AST.Token do
  @moduledoc """
  Token node representing a single word or punctuation mark.

  Uses Universal Dependencies POS tag set for cross-linguistic consistency.
  """

  alias Nasty.AST.Node

  @typedoc """
  Universal Dependencies POS tags.

  ## Open Class Words (content)
  - `:adj` - Adjective
  - `:adv` - Adverb
  - `:intj` - Interjection
  - `:noun` - Noun
  - `:propn` - Proper noun
  - `:verb` - Verb

  ## Closed Class Words (function)
  - `:adp` - Adposition (preposition/postposition)
  - `:aux` - Auxiliary verb
  - `:cconj` - Coordinating conjunction
  - `:det` - Determiner
  - `:num` - Numeral
  - `:part` - Particle
  - `:pron` - Pronoun
  - `:sconj` - Subordinating conjunction

  ## Other
  - `:punct` - Punctuation
  - `:sym` - Symbol
  - `:x` - Other (foreign words, typos, etc.)

  Reference: https://universaldependencies.org/u/pos/
  """
  @type pos_tag ::
          :adj
          | :adp
          | :adv
          | :aux
          | :cconj
          | :det
          | :intj
          | :noun
          | :num
          | :part
          | :pron
          | :propn
          | :punct
          | :sconj
          | :sym
          | :verb
          | :x

  @typedoc """
  Morphological features following Universal Dependencies.

  Common features:
  - `number`: `:singular` | `:plural`
  - `tense`: `:past` | `:present` | `:future`
  - `person`: `:first` | `:second` | `:third`
  - `case`: `:nominative` | `:accusative` | `:genitive` | etc.
  - `gender`: `:masculine` | `:feminine` | `:neuter`
  - `mood`: `:indicative` | `:subjunctive` | `:imperative`
  - `voice`: `:active` | `:passive`

  Reference: https://universaldependencies.org/u/feat/
  """
  @type morphology :: %{atom() => atom()}

  @type t :: %__MODULE__{
          text: String.t(),
          lemma: String.t(),
          pos_tag: pos_tag(),
          morphology: morphology(),
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:text, :pos_tag, :language, :span]
  defstruct [
    :text,
    :pos_tag,
    :language,
    :span,
    lemma: nil,
    morphology: %{}
  ]

  @doc """
  Creates a new token.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 3}, 3)
      iex> token = Nasty.AST.Token.new("cat", :noun, :en, span)
      iex> token.text
      "cat"
      iex> token.pos_tag
      :noun
  """
  @spec new(String.t(), pos_tag(), Node.language(), Node.span(), keyword()) :: t()
  def new(text, pos_tag, language, span, opts \\ []) do
    %__MODULE__{
      text: text,
      lemma: Keyword.get(opts, :lemma, text),
      pos_tag: pos_tag,
      morphology: Keyword.get(opts, :morphology, %{}),
      language: language,
      span: span
    }
  end

  @doc """
  Returns all supported Universal Dependencies POS tags.
  """
  @spec pos_tags() :: [pos_tag()]
  def pos_tags do
    [
      :adj,
      :adp,
      :adv,
      :aux,
      :cconj,
      :det,
      :intj,
      :noun,
      :num,
      :part,
      :pron,
      :propn,
      :punct,
      :sconj,
      :sym,
      :verb,
      :x
    ]
  end

  @doc """
  Checks if a POS tag is a content word (open class).

  ## Examples

      iex> Nasty.AST.Token.content_word?(:noun)
      true
      iex> Nasty.AST.Token.content_word?(:det)
      false
  """
  @spec content_word?(pos_tag()) :: boolean()
  def content_word?(pos_tag) do
    pos_tag in [:adj, :adv, :intj, :noun, :propn, :verb]
  end

  @doc """
  Checks if a POS tag is a function word (closed class).

  ## Examples

      iex> Nasty.AST.Token.function_word?(:det)
      true
      iex> Nasty.AST.Token.function_word?(:noun)
      false
  """
  @spec function_word?(pos_tag()) :: boolean()
  def function_word?(pos_tag) do
    pos_tag in [:adp, :aux, :cconj, :det, :num, :part, :pron, :sconj]
  end
end
