defmodule Nasty.Translation.WordOrder do
  @moduledoc """
  Handles word order transformations between languages.

  Different languages have different word order patterns:
  - Adjective placement: English pre-nominal (big cat) vs Spanish/Catalan post-nominal (gato grande)
  - Adverb placement: varies by type and language
  - Question word order: subject-verb inversion
  - Object placement: SVO vs SOV languages

  ## Usage

      alias Nasty.AST.{NounPhrase, VerbPhrase}
      alias Nasty.Translation.WordOrder

      # Reorder noun phrase from English to Spanish
      np = %NounPhrase{children: [adj, noun]}
      reordered = WordOrder.reorder_noun_phrase(np, :en, :es)
      # => %NounPhrase{children: [noun, adj]}

  """

  alias Nasty.AST.{AdjectivalPhrase, AdverbialPhrase, NounPhrase, Token, VerbPhrase}

  @doc """
  Reorders a noun phrase according to target language rules.

  English: adjective + noun (big cat)
  Spanish/Catalan: noun + adjective (gato grande)

  Exceptions:
  - Some Spanish adjectives precede noun (buen, mal, gran, viejo, joven)
  - Quantifiers and determiners always precede noun

  ## Examples

      iex> np = %NounPhrase{children: [%Token{text: "big"}, %Token{text: "cat"}]}
      iex> WordOrder.reorder_noun_phrase(np, :en, :es)
      %NounPhrase{children: [%Token{text: "cat"}, %Token{text: "big"}]}

  """
  @spec reorder_noun_phrase(NounPhrase.t(), atom(), atom()) :: NounPhrase.t()
  def reorder_noun_phrase(%NounPhrase{} = np, source_lang, target_lang) do
    case {source_lang, target_lang} do
      # English to Romance: move adjectives after noun
      {:en, lang} when lang in [:es, :ca] ->
        reorder_en_to_romance(np)

      # Romance to English: move adjectives before noun
      {lang, :en} when lang in [:es, :ca] ->
        reorder_romance_to_en(np)

      # Same order between Spanish and Catalan
      {:es, :ca} ->
        np

      {:ca, :es} ->
        np

      # No reordering needed
      _ ->
        np
    end
  end

  @doc """
  Reorders a verb phrase according to target language rules.

  Handles adverb placement and auxiliary verb order.

  ## Examples

      iex> vp = %VerbPhrase{children: [%Token{text: "often"}, %Token{text: "runs"}]}
      iex> WordOrder.reorder_verb_phrase(vp, :en, :es)
      %VerbPhrase{children: [%Token{text: "runs"}, %Token{text: "often"}]}

  """
  @spec reorder_verb_phrase(VerbPhrase.t(), atom(), atom()) :: VerbPhrase.t()
  def reorder_verb_phrase(%VerbPhrase{} = vp, source_lang, target_lang) do
    case {source_lang, target_lang} do
      # English to Romance: move frequency adverbs after verb
      {:en, lang} when lang in [:es, :ca] ->
        reorder_vp_en_to_romance(vp)

      # Romance to English: move frequency adverbs before verb
      {lang, :en} when lang in [:es, :ca] ->
        reorder_vp_romance_to_en(vp)

      # No significant difference between Spanish and Catalan
      _ ->
        vp
    end
  end

  ## Private Functions - Noun Phrase Reordering

  # English to Romance: [modifiers] [head] => [head] [post_modifiers]
  # Move adjectives from pre-modifiers to post-modifiers
  defp reorder_en_to_romance(%NounPhrase{modifiers: modifiers, post_modifiers: post_mods} = np) do
    # In English, adjectives are in modifiers (before noun)
    # In Spanish/Catalan, most adjectives go after noun (post_modifiers)
    adjectives = Enum.filter(modifiers, &adjective?/1)
    other_mods = Enum.reject(modifiers, &adjective?/1)

    %{np | modifiers: other_mods, post_modifiers: adjectives ++ post_mods}
  end

  # Romance to English: [head] [post_modifiers] => [modifiers] [head]
  # Move adjectives from post-modifiers to pre-modifiers
  defp reorder_romance_to_en(%NounPhrase{modifiers: modifiers, post_modifiers: post_mods} = np) do
    # In Spanish/Catalan, adjectives are often in post_modifiers (after noun)
    # In English, adjectives go before noun (modifiers)
    adjectives = Enum.filter(post_mods, &adjective?/1)
    other_post = Enum.reject(post_mods, &adjective?/1)

    %{np | modifiers: modifiers ++ adjectives, post_modifiers: other_post}
  end

  # Check if node is adjective
  defp adjective?(%Token{pos_tag: :ADJ}), do: true
  defp adjective?(%AdjectivalPhrase{}), do: true
  defp adjective?(_), do: false

  ## Private Functions - Verb Phrase Reordering

  # English to Romance: move frequency adverbs from auxiliaries to adverbials
  defp reorder_vp_en_to_romance(%VerbPhrase{auxiliaries: aux, adverbials: advs} = vp) do
    # In English, frequency adverbs can appear between auxiliary and main verb
    # In Spanish/Catalan, they typically go after the verb
    freq_advs = Enum.filter(aux, &frequency_adverb?/1)
    other_aux = Enum.reject(aux, &frequency_adverb?/1)

    %{vp | auxiliaries: other_aux, adverbials: advs ++ freq_advs}
  end

  # Romance to English: move frequency adverbs from adverbials to before verb
  defp reorder_vp_romance_to_en(%VerbPhrase{auxiliaries: aux, adverbials: advs} = vp) do
    # In Spanish/Catalan, frequency adverbs often follow the verb
    # In English, they typically precede the main verb
    freq_advs = Enum.filter(advs, &frequency_adverb?/1)
    other_advs = Enum.reject(advs, &frequency_adverb?/1)

    %{vp | auxiliaries: aux ++ freq_advs, adverbials: other_advs}
  end

  # Check if node is a frequency adverb
  defp frequency_adverb?(%Token{pos_tag: :ADV, text: text}) do
    freq_words = [
      "often",
      "always",
      "never",
      "sometimes",
      "usually",
      "rarely",
      "siempre",
      "nunca",
      "a menudo",
      "a veces",
      "raramente",
      "sempre",
      "mai",
      "sovint",
      "a vegades",
      "rarament"
    ]

    String.downcase(text) in freq_words
  end

  defp frequency_adverb?(%AdverbialPhrase{}), do: true
  defp frequency_adverb?(_), do: false
end
