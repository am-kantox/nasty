defmodule Nasty.Language.English.PhraseParser do
  @moduledoc """
  Phrase structure parser for English.

  Builds syntactic phrases (NounPhrase, VerbPhrase, etc.) from POS-tagged tokens
  using bottom-up pattern matching.

  ## Approach

  - **Greedy longest-match**: Consume as many tokens as possible for each phrase
  - **Bottom-up parsing**: Build smaller phrases first, then combine
  - **Left-to-right**: Process tokens in order

  ## Grammar Rules (Simplified CFG)

      NP  → Det? Adj* Noun PP*
      VP  → Aux* MainVerb NP? PP* Adv*
      PP  → Prep NP
      AdjP → Adv? Adj
      AdvP → Adv

  ## Examples

      iex> tokens = [
      ...>   %Token{text: "the", pos_tag: :det},
      ...>   %Token{text: "cat", pos_tag: :noun}
      ...> ]
      iex> PhraseParser.parse_noun_phrase(tokens, 0)
      {:ok, noun_phrase, 2}  # Consumed 2 tokens
  """

  alias Nasty.AST.{
    AdjectivalPhrase,
    AdverbialPhrase,
    Clause,
    Node,
    NounPhrase,
    PrepositionalPhrase,
    RelativeClause,
    Token,
    VerbPhrase
  }

  @doc """
  Parses a noun phrase starting at the given position.

  Grammar: Det? Adj* (Noun | PropN | Pron) PP*

  Pronouns can stand alone as NPs (e.g., "I", "he", "they").

  Returns `{:ok, noun_phrase, next_pos}` or `:error`
  """
  @spec parse_noun_phrase([Token.t()], non_neg_integer()) ::
          {:ok, NounPhrase.t(), non_neg_integer()} | :error
  def parse_noun_phrase(tokens, start_pos) when start_pos < length(tokens) do
    # Try to parse: Det? Adj* (Noun | PropN | Pron)
    {det, pos} = consume_optional(tokens, start_pos, :det)
    {modifiers, pos} = consume_while(tokens, pos, [:adj])

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

        # Merge additional PROPNs into modifiers list
        modifiers = modifiers ++ additional_propns

        # Try to parse post-modifiers (PP*)
        {post_modifiers, pos} = parse_post_modifiers(tokens, pos)

        # Calculate span
        first_token = if det, do: det, else: if(modifiers != [], do: hd(modifiers), else: head)

        last_token =
          if post_modifiers != [], do: List.last(post_modifiers) |> get_last_token(), else: head

        span =
          Node.make_span(
            first_token.span.start_pos,
            first_token.span.start_offset,
            last_token.span.end_pos,
            last_token.span.end_offset
          )

        np = %NounPhrase{
          determiner: det,
          modifiers: modifiers,
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
  Parses a verb phrase starting at the given position.

  Grammar: Aux* MainVerb NP? PP* Adv*

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
        # Treat the last auxiliary as main verb (copula construction: "is happy", "are engineers")
        main_verb = List.last(auxiliaries)
        remaining_aux = Enum.slice(auxiliaries, 0..-2//1)

        # Try to parse object (NP?)
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
  Parses a prepositional phrase starting at the given position.

  Grammar: Prep NP

  Returns `{:ok, prep_phrase, next_pos}` or `:error`
  """
  @spec parse_prepositional_phrase([Token.t()], non_neg_integer()) ::
          {:ok, PrepositionalPhrase.t(), non_neg_integer()} | :error
  def parse_prepositional_phrase(tokens, start_pos) when start_pos < length(tokens) do
    case get_token(tokens, start_pos) do
      %Token{pos_tag: tag, text: text} = prep when tag in [:adp, :sconj] and text == "than" ->
        # "than" acts like a preposition in comparative constructions
        # Try to parse NP or accept a number token
        case get_token(tokens, start_pos + 1) do
          %Token{pos_tag: :num} = num_token ->
            # Create a minimal NP from the number
            np = %NounPhrase{
              head: num_token,
              determiner: nil,
              modifiers: [],
              post_modifiers: [],
              language: num_token.language,
              span: num_token.span
            }

            span =
              Node.make_span(
                prep.span.start_pos,
                prep.span.start_offset,
                num_token.span.end_pos,
                num_token.span.end_offset
              )

            pp = %PrepositionalPhrase{
              head: prep,
              object: np,
              language: prep.language,
              span: span
            }

            {:ok, pp, start_pos + 2}

          _ ->
            # Try to parse as noun phrase
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
        end

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
  Parses an adjectival phrase starting at the given position.

  Grammar: Adv? Adj

  Returns `{:ok, adj_phrase, next_pos}` or `:error`
  """
  @spec parse_adjectival_phrase([Token.t()], non_neg_integer()) ::
          {:ok, AdjectivalPhrase.t(), non_neg_integer()} | :error
  def parse_adjectival_phrase(tokens, start_pos) when start_pos < length(tokens) do
    # Try to parse optional intensifier (Adv?)
    {intensifier, pos} = consume_optional(tokens, start_pos, :adv)

    case get_token(tokens, pos) do
      %Token{pos_tag: :adj} = head ->
        pos = pos + 1

        # Try to parse optional PP complement (e.g., "than 21", "to me")
        {complement, pos} =
          case parse_prepositional_phrase(tokens, pos) do
            {:ok, pp, new_pos} -> {pp, new_pos}
            :error -> {nil, pos}
          end

        first_token = intensifier || head
        last_token = if complement, do: get_last_token(complement), else: head

        span =
          Node.make_span(
            first_token.span.start_pos,
            first_token.span.start_offset,
            last_token.span.end_pos,
            last_token.span.end_offset
          )

        adjp = %AdjectivalPhrase{
          intensifier: intensifier,
          head: head,
          complement: complement,
          language: head.language,
          span: span
        }

        {:ok, adjp, pos}

      _ ->
        :error
    end
  end

  def parse_adjectival_phrase(_tokens, _start_pos), do: :error

  @doc """
  Parses an adverbial phrase (simple adverb for now).

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
  Parses a relative clause starting at the given position.

  Grammar: RelPron/RelAdv Clause

  Relative pronouns: who, whom, whose, which, that
  Relative adverbs: where, when, why

  Returns `{:ok, relative_clause, next_pos}` or `:error`
  """
  @spec parse_relative_clause([Token.t()], non_neg_integer()) ::
          {:ok, RelativeClause.t(), non_neg_integer()} | :error
  def parse_relative_clause(tokens, start_pos) when start_pos < length(tokens) do
    case get_token(tokens, start_pos) do
      %Token{pos_tag: tag, text: text} = relativizer ->
        lowercase_text = String.downcase(text)

        if relativizer?(tag, lowercase_text) do
          # Try to parse the rest as a clause
          # For relative clauses, the relativizer often acts as the subject
          # so we need to handle incomplete clauses
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

  # Check if a token is a relativizer
  defp relativizer?(tag, lowercase_text) when tag in [:pron, :det] do
    lowercase_text in ~w(who whom whose which that)
  end

  defp relativizer?(tag, lowercase_text) when tag in [:adv, :sconj] do
    lowercase_text in ~w(where when why)
  end

  defp relativizer?(_, _), do: false

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

      # Try adjectival phrase (e.g., "greater than 21")
      match?({:ok, _, _}, parse_adjectival_phrase(tokens, pos)) ->
        {:ok, adjp, new_pos} = parse_adjectival_phrase(tokens, pos)
        parse_post_modifiers(tokens, new_pos, [adjp | acc])

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
      # Try PP
      match?({:ok, _, _}, parse_prepositional_phrase(tokens, pos)) ->
        {:ok, pp, new_pos} = parse_prepositional_phrase(tokens, pos)
        parse_vp_complements(tokens, new_pos, [pp | acc])

      # Try Adv
      match?({:ok, _, _}, parse_adverbial_phrase(tokens, pos)) ->
        {:ok, advp, new_pos} = parse_adverbial_phrase(tokens, pos)
        parse_vp_complements(tokens, new_pos, [advp | acc])

      true ->
        {Enum.reverse(acc), pos}
    end
  end

  # Parse the body of a relative clause (after the relativizer)
  defp parse_relative_clause_body([_ | _] = tokens, _relativizer) do
    # The relativizer can function as:
    # 1. Subject: "the cat [that] [sits]" - need VP
    # 2. Object: "the cat [that] [I see]" - need NP VP

    # Try to parse as VP first (relativizer is subject)
    case parse_verb_phrase(tokens, 0) do
      {:ok, vp, end_pos} ->
        # Create a minimal clause with relativizer as implicit subject
        span = vp.span

        clause = %Clause{
          type: :relative,
          # Relativizer is the implicit subject
          subject: nil,
          predicate: vp,
          language: vp.language,
          span: span
        }

        {:ok, clause, end_pos}

      :error ->
        # Try to parse as NP VP (relativizer is object)
        case parse_noun_phrase(tokens, 0) do
          {:ok, np, np_end} ->
            case parse_verb_phrase(tokens, np_end) do
              {:ok, vp, vp_end} ->
                span =
                  Node.make_span(
                    np.span.start_pos,
                    np.span.start_offset,
                    vp.span.end_pos,
                    vp.span.end_offset
                  )

                clause = %Clause{
                  type: :relative,
                  subject: np,
                  predicate: vp,
                  language: np.language,
                  span: span
                }

                {:ok, clause, vp_end}

              :error ->
                :error
            end

          :error ->
            :error
        end
    end
  end

  defp parse_relative_clause_body(_tokens, _relativizer), do: :error

  # Get last token from a phrase structure
  defp get_last_token(%RelativeClause{clause: clause}), do: get_last_token(clause)
  defp get_last_token(%Clause{predicate: vp}), do: get_last_token(vp)
  defp get_last_token(%PrepositionalPhrase{object: np}), do: get_last_token(np)

  defp get_last_token(%NounPhrase{post_modifiers: [_ | _] = pms}),
    do: List.last(pms) |> get_last_token()

  defp get_last_token(%NounPhrase{head: head}), do: head

  defp get_last_token(%VerbPhrase{complements: [_ | _] = comps}),
    do: List.last(comps) |> get_last_token()

  defp get_last_token(%VerbPhrase{head: head}), do: head
  defp get_last_token(%AdjectivalPhrase{head: head}), do: head
  defp get_last_token(%AdverbialPhrase{head: head}), do: head
  defp get_last_token(%Token{} = token), do: token
end
