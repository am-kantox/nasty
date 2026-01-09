defmodule Nasty.Language.Catalan.PhraseParser do
  @moduledoc """
  Phrase structure parser for Catalan.

  Builds syntactic phrases (NounPhrase, VerbPhrase, etc.) from POS-tagged tokens
  using bottom-up pattern matching with Catalan word order.

  ## Catalan-Specific Features

  - Post-nominal adjectives: "la casa vermella" (the red house)
  - Pre-nominal quantifiers: "molts llibres" (many books)
  - Flexible word order: SVO is default but flexible
  - Interpunct words: treated as single lexical units
  - Clitic pronouns: em, et, es, el, la

  ## Grammar Rules (Simplified CFG)

      NP  → Det? QuantAdj* Noun Adj* PP*
      VP  → Aux* MainVerb NP? PP* Adv*
      PP  → Prep NP
      AdjP → Adv? Adj
      AdvP → Adv
  """

  alias Nasty.AST.{
    Node,
    NounPhrase,
    PrepositionalPhrase,
    Token,
    VerbPhrase
  }

  @doc """
  Parses a Catalan noun phrase starting at the given position.

  Grammar: Det? QuantAdj* (Noun | PropN | Pron) Adj* PP*

  Returns `{:ok, noun_phrase, next_pos}` or `:error`
  """
  @spec parse_noun_phrase([Token.t()], non_neg_integer()) ::
          {:ok, NounPhrase.t(), non_neg_integer()} | :error
  def parse_noun_phrase(tokens, start_pos) when start_pos < length(tokens) do
    {det, pos} = consume_optional(tokens, start_pos, :det)
    {pre_modifiers, pos} = consume_quantifying_adjectives(tokens, pos)

    case get_token(tokens, pos) do
      %Token{pos_tag: tag} = head when tag in [:noun, :propn, :pron] ->
        pos = pos + 1

        {additional_propns, pos} =
          if tag == :propn do
            consume_while(tokens, pos, [:propn])
          else
            {[], pos}
          end

        {post_adj_modifiers, pos} = consume_while(tokens, pos, [:adj])
        all_modifiers = pre_modifiers ++ additional_propns ++ post_adj_modifiers
        {post_modifiers, pos} = parse_post_modifiers(tokens, pos)

        first_token = det || if pre_modifiers != [], do: hd(pre_modifiers), else: head

        last_token =
          if post_modifiers != [],
            do: List.last(post_modifiers) |> get_last_token(),
            else: if(post_adj_modifiers != [], do: List.last(post_adj_modifiers), else: head)

        span =
          Node.make_span(
            first_token.span.start_pos,
            first_token.span.start_offset,
            last_token.span.end_pos,
            last_token.span.end_offset
          )

        np = %NounPhrase{
          determiner: det,
          modifiers: all_modifiers,
          head: head,
          post_modifiers: post_modifiers,
          language: head.language,
          span: span
        }

        {:ok, np, pos}

      _ ->
        :error
    end
  end

  def parse_noun_phrase(_tokens, _start_pos), do: :error

  @doc """
  Parses a Catalan verb phrase starting at the given position.

  Grammar: Aux* MainVerb NP? PP* Adv*

  Returns `{:ok, verb_phrase, next_pos}` or `:error`
  """
  @spec parse_verb_phrase([Token.t()], non_neg_integer()) ::
          {:ok, VerbPhrase.t(), non_neg_integer()} | :error
  def parse_verb_phrase(tokens, start_pos) when start_pos < length(tokens) do
    {auxiliaries, pos} = consume_while(tokens, start_pos, [:aux])

    case get_token(tokens, pos) do
      %Token{pos_tag: :verb} = main_verb ->
        pos = pos + 1

        {object, pos} =
          case parse_noun_phrase(tokens, pos) do
            {:ok, np, new_pos} -> {np, new_pos}
            :error -> {nil, pos}
          end

        {complements, pos} = parse_vp_complements(tokens, pos)
        first_token = if auxiliaries != [], do: hd(auxiliaries), else: main_verb

        last_token =
          if complements != [],
            do: List.last(complements) |> get_last_token(),
            else: if(object, do: get_last_token(object), else: main_verb)

        span =
          Node.make_span(
            first_token.span.start_pos,
            first_token.span.start_offset,
            last_token.span.end_pos,
            last_token.span.end_offset
          )

        vp = %VerbPhrase{
          auxiliaries: auxiliaries,
          head: main_verb,
          complements: if(object, do: [object | complements], else: complements),
          language: main_verb.language,
          span: span
        }

        {:ok, vp, pos}

      _ when auxiliaries != [] ->
        main_verb = List.last(auxiliaries)
        remaining_aux = Enum.slice(auxiliaries, 0..-2//1)

        {object, pos} =
          case parse_noun_phrase(tokens, pos) do
            {:ok, np, new_pos} -> {np, new_pos}
            :error -> {nil, pos}
          end

        {complements, pos} = parse_vp_complements(tokens, pos)
        first_token = if remaining_aux != [], do: hd(remaining_aux), else: main_verb

        last_token =
          if complements != [],
            do: List.last(complements) |> get_last_token(),
            else: if(object, do: get_last_token(object), else: main_verb)

        span =
          Node.make_span(
            first_token.span.start_pos,
            first_token.span.start_offset,
            last_token.span.end_pos,
            last_token.span.end_offset
          )

        vp = %VerbPhrase{
          auxiliaries: remaining_aux,
          head: main_verb,
          complements: if(object, do: [object | complements], else: complements),
          language: main_verb.language,
          span: span
        }

        {:ok, vp, pos}

      _ ->
        :error
    end
  end

  def parse_verb_phrase(_tokens, _start_pos), do: :error

  @doc """
  Parses a prepositional phrase.

  Grammar: Prep NP
  """
  @spec parse_prep_phrase([Token.t()], non_neg_integer()) ::
          {:ok, PrepositionalPhrase.t(), non_neg_integer()} | :error
  def parse_prep_phrase(tokens, start_pos) when start_pos < length(tokens) do
    case get_token(tokens, start_pos) do
      %Token{pos_tag: :adp} = prep ->
        case parse_noun_phrase(tokens, start_pos + 1) do
          {:ok, np, new_pos} ->
            span =
              Node.make_span(
                prep.span.start_pos,
                prep.span.start_offset,
                get_last_token(np).span.end_pos,
                get_last_token(np).span.end_offset
              )

            pp = %PrepositionalPhrase{
              head: prep,
              object: np,
              language: prep.language,
              span: span
            }

            {:ok, pp, new_pos}

          :error ->
            :error
        end

      _ ->
        :error
    end
  end

  def parse_prep_phrase(_tokens, _start_pos), do: :error

  ## Private Helpers

  defp consume_optional(tokens, pos, tag) when pos < length(tokens) do
    case get_token(tokens, pos) do
      %Token{pos_tag: ^tag} = token -> {token, pos + 1}
      _ -> {nil, pos}
    end
  end

  defp consume_optional(_tokens, pos, _tag), do: {nil, pos}

  defp consume_while(tokens, pos, tags) when pos < length(tokens) do
    consume_while_acc(tokens, pos, tags, [])
  end

  defp consume_while(_tokens, pos, _tags), do: {[], pos}

  defp consume_while_acc(tokens, pos, tags, acc) when pos < length(tokens) do
    case get_token(tokens, pos) do
      %Token{pos_tag: tag} = token ->
        if tag in tags do
          consume_while_acc(tokens, pos + 1, tags, [token | acc])
        else
          {Enum.reverse(acc), pos}
        end

      _ ->
        {Enum.reverse(acc), pos}
    end
  end

  defp consume_while_acc(_tokens, pos, _tags, acc), do: {Enum.reverse(acc), pos}

  defp consume_quantifying_adjectives(tokens, pos) do
    quantifiers = ~w(molt molta molts moltes poc poca pocs poques
                     algun alguna alguns algunes cap tot tota tots totes
                     altre altra altres)a

    consume_quantifying_acc(tokens, pos, quantifiers, [])
  end

  defp consume_quantifying_acc(tokens, pos, quantifiers, acc) when pos < length(tokens) do
    case get_token(tokens, pos) do
      %Token{pos_tag: :adj, lemma: lemma} = token ->
        if lemma in quantifiers do
          consume_quantifying_acc(tokens, pos + 1, quantifiers, [token | acc])
        else
          {Enum.reverse(acc), pos}
        end

      _ ->
        {Enum.reverse(acc), pos}
    end
  end

  defp consume_quantifying_acc(_tokens, pos, _quantifiers, acc), do: {Enum.reverse(acc), pos}

  defp parse_post_modifiers(tokens, pos) do
    parse_post_modifiers_acc(tokens, pos, [])
  end

  defp parse_post_modifiers_acc(tokens, pos, acc) when pos < length(tokens) do
    case parse_prep_phrase(tokens, pos) do
      {:ok, pp, new_pos} ->
        parse_post_modifiers_acc(tokens, new_pos, [pp | acc])

      :error ->
        {Enum.reverse(acc), pos}
    end
  end

  defp parse_post_modifiers_acc(_tokens, pos, acc), do: {Enum.reverse(acc), pos}

  defp parse_vp_complements(tokens, pos) do
    parse_vp_complements_acc(tokens, pos, [])
  end

  defp parse_vp_complements_acc(tokens, pos, acc) when pos < length(tokens) do
    cond do
      match?({:ok, _, _}, parse_prep_phrase(tokens, pos)) ->
        {:ok, pp, new_pos} = parse_prep_phrase(tokens, pos)
        parse_vp_complements_acc(tokens, new_pos, [pp | acc])

      match?(%Token{pos_tag: :adv}, get_token(tokens, pos)) ->
        adv = get_token(tokens, pos)
        parse_vp_complements_acc(tokens, pos + 1, [adv | acc])

      true ->
        {Enum.reverse(acc), pos}
    end
  end

  defp parse_vp_complements_acc(_tokens, pos, acc), do: {Enum.reverse(acc), pos}

  defp get_token(tokens, pos) when pos >= 0 and pos < length(tokens) do
    Enum.at(tokens, pos)
  end

  defp get_token(_tokens, _pos), do: nil

  defp get_last_token(%{__struct__: _} = node) do
    case node do
      %Token{} = token -> token
      %NounPhrase{post_modifiers: [_ | _] = post} -> get_last_token(List.last(post))
      %NounPhrase{modifiers: [_ | _] = mods} -> List.last(mods)
      %NounPhrase{head: head} -> head
      %VerbPhrase{complements: [_ | _] = comps} -> get_last_token(List.last(comps))
      %VerbPhrase{head: head} -> head
      %PrepositionalPhrase{object: obj} -> get_last_token(obj)
      _ -> node
    end
  end

  defp get_last_token(token), do: token
end
