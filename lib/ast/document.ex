defmodule Nasty.AST.Paragraph do
  @moduledoc """
  Paragraph node representing a sequence of related sentences.

  A paragraph is a unit of text containing one or more sentences that
  deal with a single topic or idea. Paragraphs provide discourse structure
  and cohesion markers.
  """

  alias Nasty.AST.{Node, Sentence}

  @type t :: %__MODULE__{
          sentences: [Sentence.t()],
          topic_sentence: Sentence.t() | nil,
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:sentences, :language, :span]
  defstruct [
    :sentences,
    :language,
    :span,
    topic_sentence: nil
  ]

  @doc """
  Creates a new paragraph.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {5, 0}, 100)
      iex> sentences = [s1, s2, s3]
      iex> paragraph = Nasty.AST.Paragraph.new(sentences, :en, span)
      iex> length(paragraph.sentences)
      3
  """
  @spec new([Sentence.t()], Node.language(), Node.span(), keyword()) :: t()
  def new(sentences, language, span, opts \\ []) do
    %__MODULE__{
      sentences: sentences,
      language: language,
      span: span,
      topic_sentence: Keyword.get(opts, :topic_sentence)
    }
  end

  @doc """
  Returns the first sentence of the paragraph.

  Often the topic sentence in English writing.

  ## Examples

      iex> paragraph = %Nasty.AST.Paragraph{sentences: [s1, s2, s3], ...}
      iex> Nasty.AST.Paragraph.first_sentence(paragraph)
      s1
  """
  @spec first_sentence(t()) :: Sentence.t() | nil
  def first_sentence(%__MODULE__{sentences: []}), do: nil
  def first_sentence(%__MODULE__{sentences: [first | _]}), do: first

  @doc """
  Returns the last sentence of the paragraph.

  ## Examples

      iex> paragraph = %Nasty.AST.Paragraph{sentences: [s1, s2, s3], ...}
      iex> Nasty.AST.Paragraph.last_sentence(paragraph)
      s3
  """
  @spec last_sentence(t()) :: Sentence.t() | nil
  def last_sentence(%__MODULE__{sentences: []}), do: nil
  def last_sentence(%__MODULE__{sentences: sentences}), do: List.last(sentences)

  @doc """
  Counts the number of sentences in the paragraph.

  ## Examples

      iex> paragraph = %Nasty.AST.Paragraph{sentences: [s1, s2, s3], ...}
      iex> Nasty.AST.Paragraph.sentence_count(paragraph)
      3
  """
  @spec sentence_count(t()) :: non_neg_integer()
  def sentence_count(%__MODULE__{sentences: sentences}), do: length(sentences)
end

defmodule Nasty.AST.Document do
  @moduledoc """
  Document node representing the root of the AST.

  A document is the top-level structure containing one or more paragraphs.
  It represents an entire text unit (article, email, book chapter, etc.)
  with metadata about the source and language.
  """

  alias Nasty.AST.{Node, Paragraph}

  @typedoc """
  Document metadata.

  Optional information about the document:
  - `title` - Document title
  - `author` - Author name(s)
  - `date` - Creation/modification date
  - `source` - Original source (URL, file path, etc.)
  - Custom fields as needed
  """
  @type metadata :: %{atom() => term()}

  @type t :: %__MODULE__{
          paragraphs: [Paragraph.t()],
          language: Node.language(),
          metadata: metadata(),
          semantic_frames: [Nasty.AST.Semantic.Frame.t()] | nil,
          coref_chains: [Nasty.AST.Semantic.CorefChain.t()] | nil,
          span: Node.span()
        }

  @enforce_keys [:paragraphs, :language, :span]
  defstruct [
    :paragraphs,
    :language,
    :span,
    metadata: %{},
    semantic_frames: nil,
    coref_chains: nil
  ]

  @doc """
  Creates a new document.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {100, 0}, 5000)
      iex> paragraphs = [p1, p2, p3]
      iex> doc = Nasty.AST.Document.new(paragraphs, :en, span)
      iex> length(doc.paragraphs)
      3
      
      iex> doc = Nasty.AST.Document.new(paragraphs, :en, span, 
      ...>   metadata: %{title: "My Essay", author: "Jane Doe"})
      iex> doc.metadata.title
      "My Essay"
  """
  @spec new([Paragraph.t()], Node.language(), Node.span(), keyword()) :: t()
  def new(paragraphs, language, span, opts \\ []) do
    %__MODULE__{
      paragraphs: paragraphs,
      language: language,
      span: span,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Returns all sentences in the document (flattened).

  ## Examples

      iex> doc = %Nasty.AST.Document{paragraphs: [p1, p2], ...}
      iex> sentences = Nasty.AST.Document.all_sentences(doc)
      iex> is_list(sentences)
      true
  """
  @spec all_sentences(t()) :: [Nasty.AST.Sentence.t()]
  def all_sentences(%__MODULE__{paragraphs: paragraphs}) do
    Enum.flat_map(paragraphs, fn para -> para.sentences end)
  end

  @doc """
  Counts total number of paragraphs.

  ## Examples

      iex> doc = %Nasty.AST.Document{paragraphs: [p1, p2, p3], ...}
      iex> Nasty.AST.Document.paragraph_count(doc)
      3
  """
  @spec paragraph_count(t()) :: non_neg_integer()
  def paragraph_count(%__MODULE__{paragraphs: paragraphs}), do: length(paragraphs)

  @doc """
  Counts total number of sentences across all paragraphs.

  ## Examples

      iex> doc = %Nasty.AST.Document{paragraphs: [p1, p2, p3], ...}
      iex> Nasty.AST.Document.sentence_count(doc)
      10
  """
  @spec sentence_count(t()) :: non_neg_integer()
  def sentence_count(%__MODULE__{} = doc) do
    doc
    |> all_sentences()
    |> length()
  end

  @doc """
  Returns the first paragraph of the document.

  ## Examples

      iex> doc = %Nasty.AST.Document{paragraphs: [p1, p2], ...}
      iex> Nasty.AST.Document.first_paragraph(doc)
      p1
  """
  @spec first_paragraph(t()) :: Paragraph.t() | nil
  def first_paragraph(%__MODULE__{paragraphs: []}), do: nil
  def first_paragraph(%__MODULE__{paragraphs: [first | _]}), do: first
end
