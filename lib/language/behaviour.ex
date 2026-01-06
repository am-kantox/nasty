defmodule Nasty.Language.Behaviour do
  @moduledoc """
  Behaviour that all natural language implementations must implement.

  This provides a language-agnostic interface for parsing, tagging, and rendering
  natural language text. Each language (English, Spanish, Catalan, etc.) implements
  this behaviour with language-specific rules and processing.

  ## Example Implementation

      defmodule Nasty.Language.English do
        @behaviour Nasty.Language.Behaviour
        
        @impl true
        def language_code, do: :en
        
        @impl true
        def tokenize(text, _opts) do
          # English-specific tokenization
          {:ok, tokens}
        end
        
        @impl true
        def tag_pos(tokens, _opts) do
          # English-specific POS tagging
          {:ok, tagged_tokens}
        end
        
        @impl true
        def parse(tokens, _opts) do
          # English-specific parsing
          {:ok, document_ast}
        end
        
        @impl true
        def render(ast, _opts) do
          # English-specific text generation
          {:ok, text}
        end
      end
  """

  alias Nasty.AST.{Document, Token}

  @typedoc """
  Options passed to language processing functions.

  Common options:
  - `:generate_embeddings` - Generate semantic embeddings (default: false)
  - `:parse_dependencies` - Extract dependency relations (default: true)
  - `:extract_entities` - Perform named entity recognition (default: false)
  - `:resolve_coreferences` - Resolve coreferences (default: false)
  - Custom language-specific options
  """
  @type options :: keyword()

  @typedoc """
  Parse result containing the AST and optional metadata.
  """
  @type parse_result :: {:ok, Document.t()} | {:error, term()}

  @typedoc """
  Tokenization result.
  """
  @type tokenize_result :: {:ok, [Token.t()]} | {:error, term()}

  @typedoc """
  Render result.
  """
  @type render_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Returns the ISO 639-1 language code for this implementation.

  ## Examples

      iex> Nasty.Language.English.language_code()
      :en
      
      iex> Nasty.Language.Spanish.language_code()
      :es
  """
  @callback language_code() :: atom()

  @doc """
  Tokenizes text into a list of tokens.

  Tokenization includes:
  - Sentence boundary detection
  - Word segmentation
  - Handling of contractions, hyphenation, compounds
  - Position tracking for each token

  ## Parameters

    - `text` - Raw text to tokenize
    - `opts` - Tokenization options

  ## Returns

    - `{:ok, tokens}` - List of Token structs with position information
    - `{:error, reason}` - Error during tokenization

  ## Examples

      iex> Nasty.Language.English.tokenize("Hello world.", [])
      {:ok, [
        %Token{text: "Hello", ...},
        %Token{text: "world", ...},
        %Token{text: ".", ...}
      ]}
  """
  @callback tokenize(text :: String.t(), opts :: options()) :: tokenize_result()

  @doc """
  Tags tokens with part-of-speech information.

  POS tagging assigns Universal Dependencies tags to each token
  and extracts morphological features.

  ## Parameters

    - `tokens` - List of tokens from tokenization
    - `opts` - Tagging options

  ## Returns

    - `{:ok, tagged_tokens}` - Tokens with pos_tag and morphology filled
    - `{:error, reason}` - Error during tagging

  ## Examples

      iex> tokens = [%Token{text: "cat", ...}]
      iex> Nasty.Language.English.tag_pos(tokens, [])
      {:ok, [%Token{text: "cat", pos_tag: :noun, ...}]}
  """
  @callback tag_pos(tokens :: [Token.t()], opts :: options()) :: tokenize_result()

  @doc """
  Parses tokens into a complete AST (Document structure).

  Parsing includes:
  - Phrase structure building (NP, VP, PP, etc.)
  - Clause and sentence identification
  - Dependency relation extraction (if enabled)
  - Semantic analysis (if enabled)

  ## Parameters

    - `tokens` - POS-tagged tokens
    - `opts` - Parsing options
      - `:parse_dependencies` - Extract dependency relations (default: true)
      - `:extract_entities` - Perform NER (default: false)
      - `:resolve_coreferences` - Resolve references (default: false)

  ## Returns

    - `{:ok, document}` - Complete Document AST
    - `{:error, reason}` - Parse error with details

  ## Examples

      iex> tokens = [tagged_tokens...]
      iex> Nasty.Language.English.parse(tokens, parse_dependencies: true)
      {:ok, %Document{paragraphs: [...], ...}}
  """
  @callback parse(tokens :: [Token.t()], opts :: options()) :: parse_result()

  @doc """
  Renders an AST back to natural language text.

  Rendering includes:
  - Surface realization (choosing word forms)
  - Agreement (subject-verb, determiner-noun, etc.)
  - Word order (language-specific ordering rules)
  - Punctuation insertion
  - Formatting (capitalization, spacing)

  ## Parameters

    - `ast` - AST node to render (Document, Sentence, Phrase, etc.)
    - `opts` - Rendering options

  ## Returns

    - `{:ok, text}` - Rendered natural language text
    - `{:error, reason}` - Rendering error

  ## Examples

      iex> doc = %Document{...}
      iex> Nasty.Language.English.render(doc, [])
      {:ok, "The cat sat on the mat."}
  """
  @callback render(ast :: struct(), opts :: options()) :: render_result()

  @doc """
  Returns metadata about the language implementation.

  Optional callback providing information about the implementation:
  - Version
  - Supported features
  - Performance characteristics
  - Dependencies

  ## Examples

      iex> Nasty.Language.English.metadata()
      %{
        version: "1.0.0",
        features: [:tokenization, :pos_tagging, :parsing, :ner],
        parser_type: :nimble_parsec
      }
  """
  @callback metadata() :: map()

  @optional_callbacks metadata: 0

  @doc """
  Validates that a module implements the Language.Behaviour correctly.

  ## Examples

      iex> Nasty.Language.Behaviour.validate_implementation!(Nasty.Language.English)
      :ok
  """
  @spec validate_implementation!(module()) :: :ok | no_return()
  def validate_implementation!(module) do
    required_callbacks = [
      {:language_code, 0},
      {:tokenize, 2},
      {:tag_pos, 2},
      {:parse, 2},
      {:render, 2}
    ]

    behaviours = module.__info__(:attributes)[:behaviour] || []

    unless __MODULE__ in behaviours do
      raise ArgumentError,
            "Module #{inspect(module)} does not implement Nasty.Language.Behaviour"
    end

    missing =
      Enum.filter(required_callbacks, fn {name, arity} ->
        not function_exported?(module, name, arity)
      end)

    if missing != [] do
      raise ArgumentError,
            "Module #{inspect(module)} is missing required callbacks: #{inspect(missing)}"
    end

    :ok
  end
end
