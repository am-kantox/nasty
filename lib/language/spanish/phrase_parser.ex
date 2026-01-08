defmodule Nasty.Language.Spanish.PhraseParser do
  @moduledoc """
  Phrase structure parser for Spanish.

  Builds syntactic phrases (NounPhrase, VerbPhrase, etc.) from POS-tagged tokens
  using bottom-up pattern matching with Spanish word order.

  ## Spanish-Specific Features

  - Post-nominal adjectives: "la casa roja" (the red house)
  - Pre-nominal quantifiers: "muchos libros" (many books)
  - Flexible word order: SVO is default but flexible
  - Clitic pronouns: already attached to verbs by tokenizer

  ## Grammar Rules (Simplified CFG)

      NP  → Det? QuantAdj* Noun Adj* PP*
      VP  → Aux* MainVerb NP? PP* Adv*
      PP  → Prep NP
      AdjP → Adv? Adj
      AdvP → Adv

  ## Examples

      iex> tokens = [
      ...>   %Token{text: "la", pos_tag: :det},
      ...>   %Token{text: "casa", pos_tag: :noun},
      ...>   %Token{text: "roja", pos_tag: :adj}
      ...> ]
      iex> PhraseParser.parse_noun_phrase(tokens, 0)
      {:ok, noun_phrase, 3}  # Consumed 3 tokens
  """

  alias Nasty.AST.{
    AdjectivalPhrase,
    AdverbialPhrase,
    Node,
    NounPhrase,
    PrepositionalPhrase,
    RelativeClause,
    Token,
    VerbPhrase
  }

  @doc """
  Parses a Spanish noun phrase starting at the given position.

  Grammar: Det? QuantAdj* (Noun | PropN | Pron) Adj* PP*

  Spanish adjectives typically come AFTER the noun (post-nominal),
  but quantifying adjectives come before (e.g., "muchos", "pocos").

  Returns `{:ok, noun_phrase, next_pos}` or `:error`
  """
  @spec parse_noun_phrase([Token.t()], non_neg_integer()) ::
          {:ok, NounPhrase.t(), non_neg_integer()} | :error
  def parse_noun_phrase(tokens, start_pos) when start_pos < length(tokens) do
    # Try to parse: Det? QuantAdj* (Noun | PropN | Pron)
    {det, pos} = consume_optional(tokens, start_pos, :det)

    # Consume quantifying adjectives that come before the noun
    {pre_modifiers, pos} = consume_quantifying_adjectives(tokens, pos)

    case get_token(tokens, pos) do
      %Token{pos_tag: tag} = head when tag in [:noun, :propn, :pron] ->
        pos = pos + 1

        # If head is PROPN, consume additional consecutive PROPNs (for multi-word names)
        {additional_propns, pos} =
          if tag == :propn do
            consume_while(tokens, pos, [:propn])
          else
            {[], pos}
          end

        # In Spanish, adjectives typically come AFTER the noun (post-nominal)
        {post_adj_modifiers, pos} = consume_while(tokens, pos, [:adj])

        # Combine pre and post modifiers
        all_modifiers = pre_modifiers ++ additional_propns ++ post_adj_modifiers

        # Try to parse post-modifiers (PP* | RelativeClause*)
        {post_modifiers, pos} = parse_post_modifiers(tokens, pos)

        # Calculate span
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
  Parses a Spanish verb phrase starting at the given position.

  Grammar: Aux* MainVerb NP? PP* Adv*

  Spanish verb phrases are similar to English, with:
  - Auxiliaries (haber, ser, estar) before main verb
  - Object NP after verb
  - PPs and adverbs as complements

  Returns `{:ok, verb_phrase, next_pos}` or `:error`
  """
  @spec parse_verb_phrase([Token.t()], non_neg_integer()) ::
          {:ok, VerbPhrase.t(), non_neg_integer()} | :error
  def parse_verb_phrase(tokens, start_pos) when start_pos < length(tokens) do
    # Parse auxiliaries (Aux*)
    {auxiliaries, pos} = consume_while(tokens, start_pos, [:aux])

    # Parse main verb (required)
    case get_token(tokens, pos) do
      %Token{pos_tag: :verb} = main_verb ->
        pos = pos + 1

        # Try to parse object (NP?)
        {object, pos} =
          case parse_noun_phrase(tokens, pos) do
            {:ok, np, new_pos} -> {np, new_pos}
            :error -> {nil, pos}
          end

        # Parse post-modifiers (PP* Adv*)
        {complements, pos} = parse_vp_complements(tokens, pos)

        # Calculate span
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
        # No main verb found but we have auxiliaries
        # Treat the last auxiliary as main verb (copula: "es feliz", "son ingenieros")
        main_verb = List.last(auxiliaries)
        remaining_aux = Enum.slice(auxiliaries, 0..-2//1)

        # Try to parse object (NP? or AdjP?)
        {object, pos} =
          case parse_noun_phrase(tokens, pos) do
            {:ok, np, new_pos} -> {np, new_pos}
            :error -> {nil, pos}
          end

        # Parse post-modifiers (PP* Adv*)
        {complements, pos} = parse_vp_complements(tokens, pos)

        # Calculate span
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
  Parses a Spanish prepositional phrase starting at the given position.

  Grammar: Prep NP

  Spanish prepositions: a, ante, bajo, con, contra, de, desde, en, entre, hacia, 
  hasta, para, por, según, sin, sobre, tras

  Returns `{:ok, prep_phrase, next_pos}` or `:error`
  """
  @spec parse_prepositional_phrase([Token.t()], non_neg_integer()) ::
          {:ok, PrepositionalPhrase.t(), non_neg_integer()} | :error
  def parse_prepositional_phrase(tokens, start_pos) when start_pos < length(tokens) do
    case get_token(tokens, start_pos) do
      %Token{pos_tag: :adp} = prep ->
        case parse_noun_phrase(tokens, start_pos + 1) do
          {:ok, np, next_pos} ->
            span =
              Node.make_span(
                prep.span.start_pos,
                prep.span.start_offset,
                np.span.end_pos,
                np.span.end_offset
              )

            pp = %PrepositionalPhrase{
              head: prep,
              object: np,
              language: prep.language,
              span: span
            }

            {:ok, pp, next_pos}

          :error ->
            :error
        end

      _ ->
        :error
    end
  end

  def parse_prepositional_phrase(_tokens, _start_pos), do: :error

  @doc """
  Parses a Spanish adjectival phrase starting at the given position.

  Grammar: Adv? Adj

  Examples: "muy bonita" (very pretty), "bastante grande" (quite big)

  Returns `{:ok, adj_phrase, next_pos}` or `:error`
  """
  @spec parse_adjectival_phrase([Token.t()], non_neg_integer()) ::
          {:ok, AdjectivalPhrase.t(), non_neg_integer()} | :error
  def parse_adjectival_phrase(tokens, start_pos) when start_pos < length(tokens) do
    # Try to parse optional intensifier (Adv?)
    {intensifier, pos} = consume_optional(tokens, start_pos, :adv)

    case get_token(tokens, pos) do
      %Token{pos_tag: :adj} = head ->
        first_token = intensifier || head

        span =
          Node.make_span(
            first_token.span.start_pos,
            first_token.span.start_offset,
            head.span.end_pos,
            head.span.end_offset
          )

        adjp = %AdjectivalPhrase{
          intensifier: intensifier,
          head: head,
          language: head.language,
          span: span
        }

        {:ok, adjp, pos + 1}

      _ ->
        :error
    end
  end

  def parse_adjectival_phrase(_tokens, _start_pos), do: :error

  @doc """
  Parses a Spanish adverbial phrase (simple adverb for now).

  Grammar: Adv

  Returns `{:ok, adv_phrase, next_pos}` or `:error`
  """
  @spec parse_adverbial_phrase([Token.t()], non_neg_integer()) ::
          {:ok, AdverbialPhrase.t(), non_neg_integer()} | :error
  def parse_adverbial_phrase(tokens, start_pos) when start_pos < length(tokens) do
    case get_token(tokens, start_pos) do
      %Token{pos_tag: :adv} = head ->
        advp = %AdverbialPhrase{
          head: head,
          language: head.language,
          span: head.span
        }

        {:ok, advp, start_pos + 1}

      _ ->
        :error
    end
  end

  def parse_adverbial_phrase(_tokens, _start_pos), do: :error

  @doc """
  Parses a Spanish relative clause starting at the given position.

  Grammar: RelPron/RelAdv Clause

  Relative pronouns: que, quien, quienes, cual, cuales, cuyo
  Relative adverbs: donde, cuando, como

  Returns `{:ok, relative_clause, next_pos}` or `:error`
  """
  @spec parse_relative_clause([Token.t()], non_neg_integer()) ::
          {:ok, RelativeClause.t(), non_neg_integer()} | :error
  def parse_relative_clause(tokens, start_pos) when start_pos < length(tokens) do
    case get_token(tokens, start_pos) do
      %Token{pos_tag: tag, text: text} = relativizer ->
        lowercase_text = String.downcase(text)

        if spanish_relativizer?(tag, lowercase_text) do
          # Try to parse the rest as a clause
          remaining_tokens = Enum.slice(tokens, (start_pos + 1)..-1//1)

          case parse_relative_clause_body(remaining_tokens, relativizer) do
            {:ok, clause, tokens_consumed} ->
              span =
                Node.make_span(
                  relativizer.span.start_pos,
                  relativizer.span.start_offset,
                  clause.span.end_pos,
                  clause.span.end_offset
                )

              rc = %RelativeClause{
                relativizer: relativizer,
                clause: clause,
                type: :restrictive,
                language: relativizer.language,
                span: span
              }

              {:ok, rc, start_pos + 1 + tokens_consumed}

            :error ->
              :error
          end
        else
          :error
        end

      _ ->
        :error
    end
  end

  def parse_relative_clause(_tokens, _start_pos), do: :error

  ## Private Helpers

  # Check if a token is a Spanish relativizer
  defp spanish_relativizer?(tag, lowercase_text) when tag in [:pron, :det, :sconj] do
    lowercase_text in ~w(que quien quienes cual cuales cuyo cuya cuyos cuyas)
  end

  defp spanish_relativizer?(tag, lowercase_text) when tag in [:adv] do
    lowercase_text in ~w(donde cuando como)
  end

  defp spanish_relativizer?(_, _), do: false

  # Get token at position safely
  defp get_token(tokens, pos) when pos < length(tokens), do: Enum.at(tokens, pos)
  defp get_token(_tokens, _pos), do: nil

  # Consume a single optional token of given POS tag
  defp consume_optional(tokens, pos, tag) do
    case get_token(tokens, pos) do
      %Token{pos_tag: ^tag} = token -> {token, pos + 1}
      _ -> {nil, pos}
    end
  end

  # Consume quantifying adjectives (mucho, poco, varios, etc.) that come before noun
  defp consume_quantifying_adjectives(tokens, pos) do
    consume_quantifying_adjectives(tokens, pos, [])
  end

  defp consume_quantifying_adjectives(tokens, pos, acc) do
    case get_token(tokens, pos) do
      %Token{pos_tag: :adj, text: text} = token ->
        lowercase = String.downcase(text)

        if quantifying_adjective?(lowercase) do
          consume_quantifying_adjectives(tokens, pos + 1, [token | acc])
        else
          {Enum.reverse(acc), pos}
        end

      _ ->
        {Enum.reverse(acc), pos}
    end
  end

  # Check if adjective is quantifying (comes before noun in Spanish)
  defp quantifying_adjective?(lowercase_text) do
    lowercase_text in ~w(
      mucho mucha muchos muchas
      poco poca pocos pocas
      varios varias
      alguno alguna algunos algunas
      ninguno ninguna ningunos ningunas
      todo toda todos todas
      otro otra otros otras
      cada
      ambos ambas
      sendos sendas
    )
  end

  # Consume tokens while they match any of the given POS tags
  defp consume_while(tokens, pos, tags) do
    consume_while(tokens, pos, tags, [])
  end

  defp consume_while(tokens, pos, tags, acc) do
    case get_token(tokens, pos) do
      %Token{pos_tag: tag} = token ->
        if tag in tags do
          consume_while(tokens, pos + 1, tags, [token | acc])
        else
          {Enum.reverse(acc), pos}
        end

      _ ->
        {Enum.reverse(acc), pos}
    end
  end

  # Parse post-modifiers for noun phrases (PP* | RelativeClause*)
  defp parse_post_modifiers(tokens, pos) do
    parse_post_modifiers(tokens, pos, [])
  end

  defp parse_post_modifiers(tokens, pos, acc) do
    cond do
      # Try relative clause first
      match?({:ok, _, _}, parse_relative_clause(tokens, pos)) ->
        {:ok, rc, new_pos} = parse_relative_clause(tokens, pos)
        parse_post_modifiers(tokens, new_pos, [rc | acc])

      # Try prepositional phrase
      match?({:ok, _, _}, parse_prepositional_phrase(tokens, pos)) ->
        {:ok, pp, new_pos} = parse_prepositional_phrase(tokens, pos)
        parse_post_modifiers(tokens, new_pos, [pp | acc])

      true ->
        {Enum.reverse(acc), pos}
    end
  end

  # Parse complements for verb phrases (PP* Adv*)
  defp parse_vp_complements(tokens, pos) do
    parse_vp_complements(tokens, pos, [])
  end

  defp parse_vp_complements(tokens, pos, acc) do
    cond do
      # Try prepositional phrase
      match?({:ok, _, _}, parse_prepositional_phrase(tokens, pos)) ->
        {:ok, pp, new_pos} = parse_prepositional_phrase(tokens, pos)
        parse_vp_complements(tokens, new_pos, [pp | acc])

      # Try adverbial phrase
      match?({:ok, _, _}, parse_adverbial_phrase(tokens, pos)) ->
        {:ok, advp, new_pos} = parse_adverbial_phrase(tokens, pos)
        parse_vp_complements(tokens, new_pos, [advp | acc])

      true ->
        {Enum.reverse(acc), pos}
    end
  end

  # Parse relative clause body (simplified - just parse VP for now)
  defp parse_relative_clause_body(tokens, _relativizer) do
    case parse_verb_phrase(tokens, 0) do
      {:ok, vp, pos} ->
        # Create a simple clause with the VP as predicate
        clause = %Nasty.AST.Clause{
          type: :relative,
          subject: nil,
          predicate: vp,
          language: vp.language,
          span: vp.span
        }

        {:ok, clause, pos}

      :error ->
        :error
    end
  end

  # Get last token from a phrase
  defp get_last_token(%NounPhrase{} = np) do
    if np.post_modifiers != [] do
      List.last(np.post_modifiers) |> get_last_token()
    else
      if np.modifiers != [] do
        List.last(np.modifiers)
      else
        np.head
      end
    end
  end

  defp get_last_token(%VerbPhrase{} = vp) do
    if vp.complements != [] do
      List.last(vp.complements) |> get_last_token()
    else
      vp.head
    end
  end

  defp get_last_token(%PrepositionalPhrase{} = pp) do
    get_last_token(pp.object)
  end

  defp get_last_token(%AdjectivalPhrase{} = adjp) do
    adjp.head
  end

  defp get_last_token(%AdverbialPhrase{} = advp) do
    advp.head
  end

  defp get_last_token(%RelativeClause{} = rc) do
    get_last_token(rc.clause)
  end

  defp get_last_token(%Nasty.AST.Clause{} = clause) do
    get_last_token(clause.predicate)
  end

  defp get_last_token(%Token{} = token), do: token
end
