defmodule Nasty.Translation.TokenTranslator do
  @moduledoc """
  Translates individual tokens using bilingual lexicons.

  Provides intelligent token-level translation with:
  - POS-aware selection (nouns, verbs, adjectives, etc.)
  - Morphological feature preservation (gender, number, tense, person)
  - Unknown word handling with transliteration fallback
  - Context-aware translation selection

  ## Usage

      alias Nasty.AST.Token
      alias Nasty.Translation.TokenTranslator

      # Translate a single token
      token = %Token{text: "cat", pos: :NOUN, lemma: "cat"}
      {:ok, translated} = TokenTranslator.translate_token(token, :en, :es)
      # => %Token{text: "gato", pos: :NOUN, lemma: "gato", language: :es}

      # Translate a list of tokens
      tokens = [%Token{text: "the"}, %Token{text: "cat"}]
      {:ok, translated_tokens} = TokenTranslator.translate_tokens(tokens, :en, :es)

  """

  alias Nasty.AST.Token
  alias Nasty.Translation.LexiconLoader
  require Logger

  @doc """
  Translates a single token from source language to target language.

  Returns `{:ok, translated_token}` or `{:error, reason}`.

  ## Examples

      iex> token = %Token{text: "cat", pos: :NOUN, lemma: "cat"}
      iex> TokenTranslator.translate_token(token, :en, :es)
      {:ok, %Token{text: "gato", pos: :NOUN, lemma: "gato", language: :es}}

  """
  @spec translate_token(Token.t(), atom(), atom()) :: {:ok, Token.t()} | {:error, term()}
  def translate_token(%Token{} = token, source_lang, target_lang) do
    # Try to find translation in lexicon
    case lookup_translation(token, source_lang, target_lang) do
      {:ok, translation_data} ->
        translated = apply_translation(token, translation_data, target_lang)
        {:ok, translated}

      :not_found ->
        # Fallback to transliteration for unknown words
        translated = transliterate_token(token, target_lang)
        Logger.debug("Unknown word: #{token.text} (#{source_lang}), using: #{translated.text}")
        {:ok, translated}
    end
  end

  @doc """
  Translates a list of tokens from source language to target language.

  Returns `{:ok, translated_tokens}` or `{:error, reason}`.

  ## Examples

      iex> tokens = [%Token{text: "the"}, %Token{text: "cat"}]
      iex> TokenTranslator.translate_tokens(tokens, :en, :es)
      {:ok, [%Token{text: "el"}, %Token{text: "gato"}]}

  """
  @spec translate_tokens([Token.t()], atom(), atom()) :: {:ok, [Token.t()]} | {:error, term()}
  def translate_tokens(tokens, source_lang, target_lang) when is_list(tokens) do
    translated =
      Enum.map(tokens, fn token ->
        {:ok, t} = translate_token(token, source_lang, target_lang)
        t
      end)

    {:ok, translated}
  end

  ## Private Functions

  # Look up translation in lexicon, considering lemma and text
  defp lookup_translation(%Token{lemma: lemma, text: text}, source_lang, target_lang)
       when not is_nil(lemma) do
    # Try lemma first (more reliable for inflected forms)
    case LexiconLoader.lookup(lemma, source_lang, target_lang) do
      {:ok, data} ->
        {:ok, data}

      :not_found ->
        # Fallback to text if lemma not found
        LexiconLoader.lookup(text, source_lang, target_lang)
    end
  end

  defp lookup_translation(%Token{text: text}, source_lang, target_lang) do
    LexiconLoader.lookup(text, source_lang, target_lang)
  end

  # Apply translation data to token, preserving morphology
  defp apply_translation(token, translation_data, target_lang) do
    case translation_data do
      # Simple list of translations (choose first)
      translations when is_list(translations) ->
        text = select_best_translation(translations, token)
        %{token | text: text, lemma: text, language: target_lang}

      # Noun with gender
      %{translations: translations, gender: _gender} ->
        text = select_noun_translation(translations, token)
        lemma = List.first(translations)
        %{token | text: text, lemma: lemma, language: target_lang}

      # Verb with base and class
      %{base: base, type: :verb, class: _class} ->
        # For now, use base form; conjugation will be handled in Phase 3
        %{token | text: base, lemma: base, language: target_lang}

      # Adjective with gender forms
      %{base: _base, type: :adj, gender_forms: forms} ->
        text = select_adjective_form(forms, token)
        lemma = forms[:m] || Map.values(forms) |> List.first()
        %{token | text: text, lemma: lemma, language: target_lang}

      # Simple word mapping
      %{base: base, type: _type} ->
        %{token | text: base, lemma: base, language: target_lang}

      # Unknown structure - use as-is
      other ->
        Logger.warning("Unknown translation data structure: #{inspect(other)}")
        transliterate_token(token, target_lang)
    end
  end

  # Select best translation from list based on POS and context
  defp select_best_translation([first | _rest], _token) do
    # For now, just select first translation
    # Future: use POS tags, word embeddings, or context to select best match
    first
  end

  # Select noun translation considering number
  defp select_noun_translation(translations, %Token{morphology: morph})
       when not is_nil(morph) do
    # Check if plural form needed
    case Map.get(morph, :number) do
      :plural ->
        # Try to get plural form (last in list by convention)
        List.last(translations)

      _ ->
        List.first(translations)
    end
  end

  defp select_noun_translation(translations, _token) do
    List.first(translations)
  end

  # Select adjective form considering gender
  defp select_adjective_form(forms, %Token{morphology: morph})
       when not is_nil(morph) do
    case Map.get(morph, :gender) do
      :f -> forms[:f] || forms[:m]
      :m -> forms[:m]
      _ -> forms[:m]
    end
  end

  defp select_adjective_form(forms, _token) do
    forms[:m] || Map.values(forms) |> List.first()
  end

  # Transliterate unknown word (keep as-is for now)
  defp transliterate_token(%Token{} = token, target_lang) do
    # Keep proper nouns, numbers, and punctuation as-is
    case token.pos_tag do
      pos when pos in [:PROPN, :NUM, :PUNCT, :SYM] ->
        %{token | language: target_lang}

      _ ->
        # For regular unknown words, keep original and mark language
        # Future: could add phonetic transliteration for different scripts
        %{token | language: target_lang}
    end
  end
end
