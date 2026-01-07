defmodule Nasty do
  @moduledoc """
  Nasty - Natural Abstract Syntax Treey

  A language-agnostic NLP library for Elixir that treats natural language
  with the same rigor as programming languages.

  ## Overview

  Nasty provides a comprehensive Abstract Syntax Tree (AST) representation for
  natural languages, enabling:

  - **Grammar-First Parsing**: Parse text into formal linguistic structures
  - **Multi-Language Support**: Language-agnostic architecture (English first)
  - **Bidirectional Code Conversion**: Natural Language ↔ Programming Language AST
  - **NLP Operations**: Summarization, question answering, classification
  - **Pure Elixir**: Zero external NLP dependencies

  ## Architecture

  Nasty uses a layered, behaviour-based architecture:

      Text → Tokenization → POS Tagging → Parsing → AST
                                                       ↓
                                    Semantic Analysis → Enhanced AST
                                                       ↓
                              NLP Operations / Code Interop

  Each natural language implements the `Nasty.Language.Behaviour` behaviour,
  providing language-specific tokenization, tagging, parsing, and rendering.

  ## Usage

      # Parse text to AST
      {:ok, ast} = Nasty.parse("The cat sat on the mat.", language: :en)

      # Query the AST
      subject = Nasty.Query.find_subject(ast)

      # Convert natural language to code
      {:ok, code} = Nasty.to_code("Sort the list", 
        source_language: :en, 
        target_language: :elixir
      )

      # Summarize text
      summary = Nasty.summarize(text, 
        language: :en, 
        method: :extractive, 
        sentences: 3
      )

  ## Implementation Status

  🚧 Early development - see PLAN.md for roadmap.

  Current focus:
  - Phase 0: Language abstraction layer with `@behaviour`
  - Phase 1: Universal AST schema and English implementation
  """

  alias Nasty.Interop.CodeGen.Explain
  alias Nasty.Language.{English, English.Summarizer}

  @doc """
  Returns the version and implementation status.

  ## Examples

      iex> Nasty.hello()
      {:ok, "Nasty v0.1.0 - Early Development"}

  """
  def hello do
    {:ok, "Nasty v0.1.0 - Early Development"}
  end

  @doc """
  Parse natural language text into an AST.

  ## Parameters

    - `text`: The text to parse
    - `opts`: Keyword options
      - `:language` - Language code (`:en`, `:es`, `:ca`, etc.) **Required for now**
      - `:tokenize` - Enable tokenization (default: true)
      - `:pos_tag` - Enable POS tagging (default: true)
      - `:parse_dependencies` - Parse dependency relationships (default: true)
      - `:extract_entities` - Extract named entities (default: false)
      - `:resolve_coreferences` - Resolve coreferences (default: false)

  ## Examples

      {:ok, ast} = Nasty.parse("The cat sat.", language: :en)

  ## Returns

    - `{:ok, %Nasty.AST.Document{}}` - Parsed AST
    - `{:error, reason}` - Parse error

  """
  def parse(text, opts \\ []) do
    with {:ok, language_code} <- get_language(text, opts),
         {:ok, module} <- Nasty.Language.Registry.get(language_code),
         {:ok, tokens} <- module.tokenize(text, opts),
         {:ok, tagged_tokens} <- module.tag_pos(tokens, opts),
         {:ok, document} <- module.parse(tagged_tokens, opts) do
      {:ok, document}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Renders an AST back to natural language text.

  The language is determined from the AST's language field.

  ## Examples

      {:ok, text} = Nasty.render(ast)

  ## Returns

    - `{:ok, text}` - Rendered text
    - `{:error, reason}` - Render error
  """
  @spec render(struct(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(ast, opts \\ []) do
    language_code = get_ast_language(ast)

    case Nasty.Language.Registry.get(language_code) do
      {:ok, module} -> module.render(ast, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Summarizes a document by extracting important sentences.

  ## Parameters

    - `text_or_ast`: Text string or AST Document to summarize
    - `opts`: Keyword options
      - `:language` - Language code (`:en`, `:es`, `:ca`, etc.) (required if text)
      - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
      - `:max_sentences` - Maximum number of sentences in summary
      - `:method` - Selection method: `:greedy` or `:mmr` (default: `:greedy`)

  ## Examples

      {:ok, summary} = Nasty.summarize(text, language: :en, ratio: 0.3)
      
      # Or with AST directly
      {:ok, ast} = Nasty.parse(text, language: :en)
      {:ok, summary} = Nasty.summarize(ast, max_sentences: 3)

  ## Returns

    - `{:ok, [%Sentence{}]}` - List of extracted sentences
    - `{:error, reason}` - Error
  """
  @spec summarize(String.t() | struct(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def summarize(text_or_ast, opts \\ [])

  def summarize(text, opts) when is_binary(text) do
    with {:ok, ast} <- parse(text, opts) do
      summarize(ast, opts)
    end
  end

  def summarize(%Nasty.AST.Document{language: language} = document, opts) do
    case Nasty.Language.Registry.get(language) do
      {:ok, Nasty.Language.English} ->
        {:ok, Summarizer.summarize(document, opts)}

      {:ok, _module} ->
        {:error, :summarization_not_supported}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def summarize(_, _opts), do: {:error, :invalid_input}

  @doc """
  Converts natural language text to code.

  ## Parameters

    - `text`: Natural language description of what the code should do
    - `opts`: Keyword options
      - `:source_language` - Source natural language (`:en`, etc.) (required)
      - `:target_language` - Target programming language (`:elixir`, etc.) (required)

  ## Examples

      {:ok, code} = Nasty.to_code("Sort the list", 
        source_language: :en, 
        target_language: :elixir
      )
      # => "Enum.sort(list)"

  ## Returns

    - `{:ok, code_string}` - Generated code
    - `{:error, reason}` - Error
  """
  @spec to_code(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_code(text, opts \\ []) do
    source_language = Keyword.get(opts, :source_language)
    target_language = Keyword.get(opts, :target_language)

    cond do
      is_nil(source_language) ->
        {:error, :source_language_required}

      is_nil(target_language) ->
        {:error, :target_language_required}

      source_language == :en and target_language == :elixir ->
        English.to_code(text, opts)

      true ->
        {:error, {:unsupported_language_pair, source_language, target_language}}
    end
  end

  @doc """
  Generates natural language explanation from code.

  ## Parameters

    - `code`: Code string or AST to explain
    - `opts`: Keyword options
      - `:source_language` - Programming language (`:elixir`, etc.) (required)
      - `:target_language` - Target natural language (`:en`, etc.) (required)
      - `:style` - Explanation style: `:concise` or `:verbose` (default: `:concise`)

  ## Examples

      {:ok, explanation} = Nasty.explain_code("Enum.sort(list)",
        source_language: :elixir,
        target_language: :en
      )
      # => "Sort list"

  ## Returns

    - `{:ok, explanation_string}` - Natural language explanation
    - `{:error, reason}` - Error
  """
  @spec explain_code(String.t() | Macro.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def explain_code(code, opts \\ []) do
    source_language = Keyword.get(opts, :source_language)
    target_language = Keyword.get(opts, :target_language, :en)

    cond do
      is_nil(source_language) ->
        {:error, :source_language_required}

      source_language == :elixir and target_language == :en ->
        Explain.explain_code(code, Keyword.put(opts, :language, :en))

      true ->
        {:error, {:unsupported_language_pair, source_language, target_language}}
    end
  end

  ## Private Helpers

  # Gets language from options or attempts auto-detection
  defp get_language(_text, opts) do
    case Keyword.get(opts, :language) do
      nil ->
        {:error, :language_required}

      language_code when is_atom(language_code) ->
        if Nasty.Language.Registry.registered?(language_code) do
          {:ok, language_code}
        else
          {:error, {:language_not_registered, language_code}}
        end

      invalid ->
        {:error, {:invalid_language_code, invalid}}
    end
  end

  # Extracts language from AST node
  defp get_ast_language(%{language: lang}) when is_atom(lang), do: lang
  defp get_ast_language(_), do: :unknown
end
