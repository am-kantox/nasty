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
