defmodule Nasty.Language.Catalan.Parser do
  @moduledoc """
  Parser for Catalan sentences and phrases.

  Builds a complete Document AST from POS-tagged tokens by:
  1. Parsing sentences into clause structures
  2. Constructing paragraphs from sentences
  3. Creating document with proper span tracking
  4. Adding metadata (token count, sentence count)

  ## Examples

      iex> {:ok, tokens} = Catalan.Tokenizer.tokenize("El gat dorm.")
      iex> {:ok, tagged} = Catalan.POSTagger.tag_pos(tokens)
      iex> {:ok, analyzed} = Catalan.Morphology.analyze(tagged)
      iex> Parser.parse(analyzed)
      {:ok, %Document{paragraphs: [%Paragraph{sentences: [...]}]}}
  """

  alias Nasty.AST.{Document, Node, Paragraph, Token}
  alias Nasty.Language.Catalan.SentenceParser

  @doc """
  Parses morphologically-analyzed Catalan tokens into a Document AST.

  ## Options

  - `:dependencies` - Extract dependency relations (default: false)
  - `:entities` - Recognize named entities (default: false)
  - `:semantic_roles` - Extract semantic roles (default: false)

  ## Returns

  `{:ok, document}` on success, `{:error, reason}` on failure.
  """
  @spec parse([Token.t()], keyword()) :: {:ok, Document.t()} | {:error, term()}
  def parse(tokens, opts \\ [])

  def parse([], _opts) do
    # Empty document
    empty_span = Node.make_span({1, 0}, 0, {1, 0}, 0)

    document = %Document{
      paragraphs: [],
      span: empty_span,
      language: :ca,
      metadata: %{
        source: "parsed",
        token_count: 0,
        sentence_count: 0,
        tokens: []
      }
    }

    {:ok, document}
  end

  def parse(tokens, opts) when is_list(tokens) do
    # Parse sentences from tokens
    with {:ok, sentences} <- SentenceParser.parse_sentences(tokens, opts) do
      # Calculate document span
      doc_span =
        if Enum.empty?(sentences) do
          # Empty document
          Node.make_span({1, 0}, 0, {1, 0}, 0)
        else
          first = hd(sentences)
          last = List.last(sentences)

          Node.make_span(
            first.span.start_pos,
            first.span.start_offset,
            last.span.end_pos,
            last.span.end_offset
          )
        end

      # Create paragraph from sentences
      paragraph = %Paragraph{
        sentences: sentences,
        span: doc_span,
        language: :ca
      }

      # Create base document
      document = %Document{
        paragraphs: [paragraph],
        span: doc_span,
        language: :ca,
        metadata: %{
          source: "parsed",
          token_count: length(tokens),
          sentence_count: length(sentences),
          tokens: tokens
        }
      }

      # TODO: Optionally add semantic analysis when implemented
      # document =
      #   document
      #   |> maybe_add_semantic_frames(opts)
      #   |> maybe_add_coreference_chains(opts)

      {:ok, document}
    end
  end
end
