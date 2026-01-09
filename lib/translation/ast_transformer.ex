defmodule Nasty.Translation.ASTTransformer do
  @moduledoc """
  Transforms Abstract Syntax Trees between languages.

  Orchestrates the complete translation pipeline:
  1. Token translation (word-level)
  2. Word order adjustment (phrase structure)
  3. Agreement enforcement (morphology)

  Works recursively on AST nodes from top to bottom.

  ## Usage

      alias Nasty.AST.Document
      alias Nasty.Translation.ASTTransformer

      # Transform complete document
      {:ok, translated_doc} = ASTTransformer.transform(document, :en, :es)

  """

  alias Nasty.AST.{
    AdjectivalPhrase,
    AdverbialPhrase,
    Clause,
    Document,
    NounPhrase,
    Paragraph,
    PrepositionalPhrase,
    Sentence,
    Token,
    VerbPhrase
  }

  alias Nasty.Translation.{Agreement, TokenTranslator, WordOrder}

  @doc """
  Transforms an AST node from source to target language.

  Returns `{:ok, transformed_node}` or `{:error, reason}`.

  ## Examples

      iex> doc = %Document{language: :en, ...}
      iex> ASTTransformer.transform(doc, :en, :es)
      {:ok, %Document{language: :es, ...}}

  """
  @spec transform(term(), atom(), atom()) :: {:ok, term()} | {:error, term()}
  def transform(node, source_lang, target_lang)

  # Document
  def transform(%Document{paragraphs: paragraphs} = doc, source_lang, target_lang) do
    {:ok, transformed_paras} = transform_list(paragraphs, source_lang, target_lang)
    {:ok, %{doc | paragraphs: transformed_paras, language: target_lang}}
  end

  # Paragraph
  def transform(%Paragraph{sentences: sentences} = para, source_lang, target_lang) do
    {:ok, transformed_sents} = transform_list(sentences, source_lang, target_lang)
    {:ok, %{para | sentences: transformed_sents, language: target_lang}}
  end

  # Sentence
  def transform(
        %Sentence{main_clause: main, additional_clauses: additional} = sent,
        source_lang,
        target_lang
      ) do
    {:ok, transformed_main} = transform(main, source_lang, target_lang)
    {:ok, transformed_additional} = transform_list(additional, source_lang, target_lang)

    {:ok,
     %{
       sent
       | main_clause: transformed_main,
         additional_clauses: transformed_additional,
         language: target_lang
     }}
  end

  # Clause
  def transform(
        %Clause{subject: subject, predicate: predicate, subordinator: sub} = clause,
        source_lang,
        target_lang
      ) do
    {:ok, transformed_subject} = transform_optional(subject, source_lang, target_lang)
    {:ok, transformed_predicate} = transform(predicate, source_lang, target_lang)
    {:ok, transformed_sub} = transform_optional(sub, source_lang, target_lang)

    transformed_clause = %{
      clause
      | subject: transformed_subject,
        predicate: transformed_predicate,
        subordinator: transformed_sub,
        language: target_lang
    }

    # Enforce subject-verb agreement
    agreed_clause = Agreement.enforce_subject_verb_agreement(transformed_clause, target_lang)

    {:ok, agreed_clause}
  end

  # Noun Phrase
  def transform(
        %NounPhrase{
          determiner: det,
          modifiers: mods,
          head: head,
          post_modifiers: post_mods
        } = np,
        source_lang,
        target_lang
      ) do
    # Translate all tokens
    {:ok, trans_det} = transform_optional(det, source_lang, target_lang)
    {:ok, trans_mods} = transform_list(mods, source_lang, target_lang)
    {:ok, trans_head} = transform(head, source_lang, target_lang)
    {:ok, trans_post_mods} = transform_list(post_mods, source_lang, target_lang)

    # Build translated noun phrase
    translated_np = %{
      np
      | determiner: trans_det,
        modifiers: trans_mods,
        head: trans_head,
        post_modifiers: trans_post_mods,
        language: target_lang
    }

    # Apply word order transformation
    reordered_np = WordOrder.reorder_noun_phrase(translated_np, source_lang, target_lang)

    # Enforce gender/number agreement
    agreed_np = Agreement.enforce_noun_phrase_agreement(reordered_np, target_lang)

    {:ok, agreed_np}
  end

  # Verb Phrase
  def transform(
        %VerbPhrase{
          auxiliaries: aux,
          head: head,
          complements: comps,
          adverbials: advs
        } = vp,
        source_lang,
        target_lang
      ) do
    # Translate all components
    {:ok, trans_aux} = transform_list(aux, source_lang, target_lang)
    {:ok, trans_head} = transform(head, source_lang, target_lang)
    {:ok, trans_comps} = transform_list(comps, source_lang, target_lang)
    {:ok, trans_advs} = transform_list(advs, source_lang, target_lang)

    # Build translated verb phrase
    translated_vp = %{
      vp
      | auxiliaries: trans_aux,
        head: trans_head,
        complements: trans_comps,
        adverbials: trans_advs,
        language: target_lang
    }

    # Apply word order transformation
    reordered_vp = WordOrder.reorder_verb_phrase(translated_vp, source_lang, target_lang)

    {:ok, reordered_vp}
  end

  # Prepositional Phrase
  def transform(%PrepositionalPhrase{head: prep, object: obj} = pp, source_lang, target_lang) do
    {:ok, trans_prep} = transform(prep, source_lang, target_lang)
    {:ok, trans_obj} = transform(obj, source_lang, target_lang)

    {:ok, %{pp | head: trans_prep, object: trans_obj, language: target_lang}}
  end

  # Adjectival Phrase
  def transform(
        %AdjectivalPhrase{intensifier: int, head: head, complement: comp} = adjp,
        source_lang,
        target_lang
      ) do
    {:ok, trans_int} = transform_optional(int, source_lang, target_lang)
    {:ok, trans_head} = transform(head, source_lang, target_lang)
    {:ok, trans_comp} = transform_optional(comp, source_lang, target_lang)

    {:ok,
     %{
       adjp
       | intensifier: trans_int,
         head: trans_head,
         complement: trans_comp,
         language: target_lang
     }}
  end

  # Adverbial Phrase
  def transform(
        %AdverbialPhrase{intensifier: int, head: head} = advp,
        source_lang,
        target_lang
      ) do
    {:ok, trans_int} = transform_optional(int, source_lang, target_lang)
    {:ok, trans_head} = transform(head, source_lang, target_lang)

    {:ok, %{advp | intensifier: trans_int, head: trans_head, language: target_lang}}
  end

  # Token (leaf node)
  def transform(%Token{} = token, source_lang, target_lang) do
    TokenTranslator.translate_token(token, source_lang, target_lang)
  end

  # Fallback for unknown nodes
  def transform(node, _source_lang, _target_lang) do
    {:ok, node}
  end

  ## Private Helper Functions

  # Transform a list of nodes
  defp transform_list(nodes, source_lang, target_lang) when is_list(nodes) do
    transformed =
      Enum.map(nodes, fn node ->
        {:ok, t} = transform(node, source_lang, target_lang)
        t
      end)

    {:ok, transformed}
  end

  # Transform optional node (nil or present)
  defp transform_optional(nil, _source_lang, _target_lang), do: {:ok, nil}

  defp transform_optional(node, source_lang, target_lang) do
    transform(node, source_lang, target_lang)
  end
end
