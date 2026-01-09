defmodule Nasty.Translation.Translator do
  @moduledoc """
  Cross-lingual translation using AST-based transformation.

  Translates between English, Spanish, and Catalan by:
  1. Parsing source text to language-agnostic AST
  2. Transforming AST tokens and structure for target language
  3. Rendering AST in target language

  This approach preserves syntactic structure and provides transparent,
  linguistically-motivated translations without neural models.

  ## Supported Language Pairs

  - English ↔ Spanish (en ↔ es)
  - English ↔ Catalan (en ↔ ca)
  - Spanish ↔ Catalan (es ↔ ca)

  ## Examples

      # Simple translation
      iex> Translator.translate("The cat sleeps", :en, :es)
      {:ok, "El gato duerme"}

      # Automatic source language detection
      iex> Translator.translate("El gato duerme", :auto, :en)
      {:ok, "The cat sleeps"}

      # With AST inspection
      iex> {:ok, doc} = English.parse("The red car")
      iex> Translator.translate_document(doc, :es)
      {:ok, %Document{language: :es, ...}}

  ## Options

  - `:preserve_structure` - Keep original AST structure (default: true)
  - `:handle_unknowns` - Strategy for unknown words: :keep, :skip (default: :keep)
  - `:debug` - Return intermediate AST transformations (default: false)

  ## Limitations

  - Lexicon-based: Unknown words are passed through untranslated
  - No context-based disambiguation (yet)
  - Idioms require explicit entries in lexicon
  - Gender assignment for English nouns uses defaults
  """

  alias Nasty.AST.{Document, Renderer}
  alias Nasty.Language.{Catalan, English, Registry, Spanish}
  alias Nasty.Translation.ASTTransformer

  require Logger

  @supported_languages [:en, :es, :ca]

  @typedoc "Language code"
  @type language :: :en | :es | :ca | :auto

  @typedoc "Translation options"
  @type options :: [
          preserve_structure: boolean(),
          handle_unknowns: :keep | :skip,
          debug: boolean()
        ]

  @doc """
  Translates text from source language to target language.

  ## Examples

      iex> Translator.translate("The cat sleeps", :en, :es)
      {:ok, "El gato duerme"}

      iex> Translator.translate("Hola mundo", :es, :en)
      {:ok, "Hello world"}

      iex> Translator.translate("El gat dorm", :ca, :es)
      {:ok, "El gato duerme"}

  ## Options

  - `:preserve_structure` - Keep original AST structure (default: true)
  - `:handle_unknowns` - Strategy for unknown words: :keep, :skip (default: :keep)

  """
  @spec translate(String.t(), language(), language(), options()) ::
          {:ok, String.t()} | {:error, term()}
  def translate(text, source_lang, target_lang, opts \\ [])

  def translate("", _source_lang, _target_lang, _opts) do
    {:ok, ""}
  end

  def translate(text, source_lang, target_lang, opts) when is_binary(text) do
    with {:ok, source} <- resolve_source_language(text, source_lang),
         {:ok, target} <- validate_target_language(target_lang),
         :ok <- validate_language_pair(source, target),
         {:ok, document} <- parse_source(text, source),
         {:ok, translated_doc} <- translate_document(document, target, opts) do
      render_target(translated_doc, target)
    end
  end

  @doc """
  Translates an already-parsed document to target language.

  Useful when you want to inspect or modify the AST before/after translation.

  ## Examples

      iex> {:ok, doc} = English.parse("The cat sleeps")
      iex> Translator.translate_document(doc, :es)
      {:ok, %Document{language: :es, ...}}

  """
  @spec translate_document(Document.t(), language(), options()) ::
          {:ok, Document.t()} | {:error, term()}
  def translate_document(document, target_lang, opts \\ [])

  def translate_document(%Document{language: source_lang} = document, target_lang, _opts) do
    with {:ok, target} <- validate_target_language(target_lang),
         :ok <- validate_language_pair(source_lang, target) do
      # Use ASTTransformer for complete translation
      ASTTransformer.transform(document, source_lang, target)
    end
  end

  @doc """
  Lists all supported language pairs.

  ## Examples

      iex> Translator.supported_pairs()
      [
        {:en, :es}, {:es, :en},
        {:en, :ca}, {:ca, :en},
        {:es, :ca}, {:ca, :es}
      ]

  """
  @spec supported_pairs() :: [{language(), language()}]
  def supported_pairs do
    for source <- @supported_languages,
        target <- @supported_languages,
        source != target,
        do: {source, target}
  end

  @doc """
  Checks if a language pair is supported.

  ## Examples

      iex> Translator.supports?(:en, :es)
      true

      iex> Translator.supports?(:en, :fr)
      false

  """
  @spec supports?(language(), language()) :: boolean()
  def supports?(source, target)
      when source in @supported_languages and target in @supported_languages do
    source != target
  end

  def supports?(_source, _target), do: false

  # Private functions

  defp resolve_source_language(_text, lang) when lang in @supported_languages do
    {:ok, lang}
  end

  defp resolve_source_language(text, :auto) do
    case Registry.detect_language(text) do
      {:ok, lang} when lang in @supported_languages ->
        Logger.debug("Detected source language: #{lang}")
        {:ok, lang}

      {:ok, lang} ->
        {:error, {:unsupported_language, lang}}

      {:error, reason} ->
        {:error, {:language_detection_failed, reason}}
    end
  end

  defp resolve_source_language(_text, lang) do
    {:error, {:unsupported_language, lang}}
  end

  defp validate_target_language(lang) when lang in @supported_languages do
    {:ok, lang}
  end

  defp validate_target_language(lang) do
    {:error, {:unsupported_language, lang}}
  end

  defp validate_language_pair(source, target) when source == target do
    {:error, :same_language}
  end

  defp validate_language_pair(_source, _target) do
    :ok
  end

  defp parse_source(text, :en) do
    with {:ok, tokens} <- English.tokenize(text),
         {:ok, tagged} <- English.tag_pos(tokens) do
      English.parse(tagged)
    end
  end

  defp parse_source(text, :es) do
    with {:ok, tokens} <- Spanish.tokenize(text),
         {:ok, tagged} <- Spanish.tag_pos(tokens) do
      Spanish.parse(tagged)
    end
  end

  defp parse_source(text, :ca) do
    with {:ok, tokens} <- Catalan.tokenize(text),
         {:ok, tagged} <- Catalan.tag_pos(tokens) do
      Catalan.parse(tagged)
    end
  end

  defp render_target(document, _lang) do
    # Use generic AST.Renderer for all languages
    Renderer.render(document)
  end
end
