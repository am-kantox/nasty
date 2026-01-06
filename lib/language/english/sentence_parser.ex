defmodule Nasty.Language.English.SentenceParser do
  @moduledoc """
  Sentence and clause parser for English.

  Builds Clause and Sentence structures from phrases.

  ## Approach

  - Parse simple clauses: Subject (NP) + Predicate (VP)
  - Identify sentence boundaries using punctuation
  - Handle basic sentence types (declarative, interrogative, imperative)

  ## Examples

      iex> tokens = [...]  # "The cat sat."
      iex> SentenceParser.parse_sentences(tokens)
      {:ok, [sentence]}
  """

  alias Nasty.AST.{Clause, Node, Sentence, Token}
  alias Nasty.Language.English.PhraseParser

  @doc """
  Parses tokens into a list of sentences.

  Identifies sentence boundaries and parses each sentence separately.
  """
  @spec parse_sentences([Token.t()]) :: {:ok, [Sentence.t()]} | {:error, term()}
  def parse_sentences(tokens) do
    # Split on sentence-ending punctuation
    sentence_groups = split_sentences(tokens)

    sentences =
      sentence_groups
      |> Enum.map(&parse_sentence/1)
      |> Enum.reject(&is_nil/1)

    {:ok, sentences}
  end

  @doc """
  Parses a single sentence from tokens.

  Grammar: NP VP (simplified for Phase 3)
  """
  @spec parse_sentence([Token.t()]) :: Sentence.t() | nil
  def parse_sentence([]), do: nil

  def parse_sentence(tokens) do
    # Remove trailing punctuation for parsing
    {sentence_tokens, punct} = strip_trailing_punct(tokens)

    if Enum.empty?(sentence_tokens) do
      nil
    else
      # Try to parse clause (may be simple, coordinated, or subordinate)
      case parse_clause(sentence_tokens) do
        {:ok, clauses} when is_list(clauses) ->
          # Multiple coordinated clauses
          [main_clause | additional] = clauses
          function = infer_function(punct)

          first_token = hd(tokens)
          last_token = List.last(tokens)

          span =
            Node.make_span(
              first_token.span.start_pos,
              first_token.span.start_offset,
              last_token.span.end_pos,
              last_token.span.end_offset
            )

          structure = if additional != [], do: :compound, else: :simple

          %Sentence{
            function: function,
            structure: structure,
            main_clause: main_clause,
            additional_clauses: additional,
            language: main_clause.language,
            span: span
          }

        {:ok, %Clause{type: :subordinate} = subord_clause} ->
          # Subordinate clause - this shouldn't happen at sentence level
          # but handle gracefully
          function = infer_function(punct)

          first_token = hd(tokens)
          last_token = List.last(tokens)

          span =
            Node.make_span(
              first_token.span.start_pos,
              first_token.span.start_offset,
              last_token.span.end_pos,
              last_token.span.end_offset
            )

          %Sentence{
            function: function,
            structure: :fragment,
            main_clause: subord_clause,
            language: subord_clause.language,
            span: span
          }

        {:ok, clause} when is_struct(clause, Clause) ->
          # Determine sentence function from punctuation
          function = infer_function(punct)

          # Calculate span including punctuation
          first_token = hd(tokens)
          last_token = List.last(tokens)

          span =
            Node.make_span(
              first_token.span.start_pos,
              first_token.span.start_offset,
              last_token.span.end_pos,
              last_token.span.end_offset
            )

          %Sentence{
            function: function,
            structure: :simple,
            main_clause: clause,
            language: clause.language,
            span: span
          }

        :error ->
          # Fallback: create minimal sentence
          create_fallback_sentence(tokens)
      end
    end
  end

  @doc """
  Parses a clause from tokens, detecting coordination and subordination.

  Grammar: 
    Simple: (NP) VP
    Coordinated: Clause CoordConj Clause
    Subordinate: SubordConj Clause
  """
  @spec parse_clause([Token.t()]) :: {:ok, Clause.t() | [Clause.t()]} | :error
  def parse_clause([_ | _] = tokens) do
    # Check for subordinating conjunction at start
    case get_subordinator(tokens, 0) do
      {subord_token, rest_pos} ->
        # Parse subordinate clause
        case parse_simple_clause(Enum.drop(tokens, rest_pos)) do
          {:ok, clause} ->
            subordinate_clause = %{clause | type: :subordinate, subordinator: subord_token}
            {:ok, subordinate_clause}

          :error ->
            parse_simple_clause(tokens)
        end

      nil ->
        # Check for coordination
        case find_coordinating_conj(tokens) do
          {conj_pos, _conj_token} ->
            # Split and parse both clauses
            left_tokens = Enum.slice(tokens, 0, conj_pos)
            right_tokens = Enum.slice(tokens, (conj_pos + 1)..-1//1)

            with {:ok, left_clause} <- parse_simple_clause(left_tokens),
                 {:ok, right_clause} <- parse_simple_clause(right_tokens) do
              {:ok, [left_clause, right_clause]}
            else
              _ -> parse_simple_clause(tokens)
            end

          nil ->
            parse_simple_clause(tokens)
        end
    end
  end

  def parse_clause(_), do: :error

  # Parses a simple clause from tokens.
  # Grammar: (NP) VP
  # Subject is optional for imperative sentences.
  @spec parse_simple_clause([Token.t()]) :: {:ok, Clause.t()} | :error
  defp parse_simple_clause([_ | _] = tokens) do
    # Try to find a verb to identify the predicate
    verb_pos = Enum.find_index(tokens, fn t -> t.pos_tag in [:verb, :aux] end)

    case verb_pos do
      nil ->
        # No verb found - not a valid clause
        :error

      0 ->
        # Verb at start - likely imperative (no subject)
        case PhraseParser.parse_verb_phrase(tokens, 0) do
          {:ok, vp, _} ->
            span = vp.span

            clause = %Clause{
              type: :independent,
              predicate: vp,
              subject: nil,
              language: vp.language,
              span: span
            }

            {:ok, clause}

          :error ->
            :error
        end

      _ ->
        # Try to parse subject before verb
        case PhraseParser.parse_noun_phrase(tokens, 0) do
          {:ok, subject, subj_end} when subj_end <= verb_pos ->
            # Parse predicate starting at or after subject
            case PhraseParser.parse_verb_phrase(tokens, subj_end) do
              {:ok, predicate, _} ->
                span =
                  Node.make_span(
                    subject.span.start_pos,
                    subject.span.start_offset,
                    predicate.span.end_pos,
                    predicate.span.end_offset
                  )

                clause = %Clause{
                  type: :independent,
                  subject: subject,
                  predicate: predicate,
                  language: subject.language,
                  span: span
                }

                {:ok, clause}

              :error ->
                :error
            end

          _ ->
            # No subject, try just VP
            case PhraseParser.parse_verb_phrase(tokens, verb_pos) do
              {:ok, vp, _} ->
                span = vp.span

                clause = %Clause{
                  type: :independent,
                  predicate: vp,
                  subject: nil,
                  language: vp.language,
                  span: span
                }

                {:ok, clause}

              :error ->
                :error
            end
        end
    end
  end

  defp parse_simple_clause(_), do: :error

  ## Private Helpers

  # Split tokens into sentence groups based on punctuation
  defp split_sentences(tokens) do
    tokens
    |> Enum.chunk_by(fn token ->
      token.pos_tag == :punct and token.text in [".", "!", "?"]
    end)
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [sentence, [punct]] -> sentence ++ [punct]
      [sentence] -> sentence
    end)
    |> Enum.reject(&Enum.empty?/1)
  end

  # Strip trailing punctuation
  defp strip_trailing_punct(tokens) do
    case List.last(tokens) do
      %Token{pos_tag: :punct} = punct ->
        {Enum.slice(tokens, 0..-2//1), punct}

      _ ->
        {tokens, nil}
    end
  end

  # Infer sentence function from punctuation
  defp infer_function(%Token{text: "?"}), do: :interrogative
  defp infer_function(%Token{text: "!"}), do: :exclamative
  defp infer_function(_), do: :declarative

  # Get subordinating conjunction at position if present
  defp get_subordinator(tokens, pos) do
    case Enum.at(tokens, pos) do
      %Token{pos_tag: :sconj} = token -> {token, pos + 1}
      _ -> nil
    end
  end

  # Find first coordinating conjunction in tokens
  defp find_coordinating_conj(tokens) do
    Enum.with_index(tokens)
    |> Enum.find(fn {token, _idx} -> token.pos_tag == :cconj end)
    |> case do
      {token, idx} -> {idx, token}
      nil -> nil
    end
  end

  # Create a fallback sentence when parsing fails
  defp create_fallback_sentence(tokens) do
    # Find any verb to use as predicate head
    verb_token = Enum.find(tokens, fn t -> t.pos_tag in [:verb, :aux] end) || hd(tokens)

    first_token = hd(tokens)
    last_token = List.last(tokens)

    span =
      Node.make_span(
        first_token.span.start_pos,
        first_token.span.start_offset,
        last_token.span.end_pos,
        last_token.span.end_offset
      )

    # Create minimal VP
    vp = %Nasty.AST.VerbPhrase{
      head: verb_token,
      language: verb_token.language,
      span: verb_token.span
    }

    # Create minimal clause
    clause = %Clause{
      type: :independent,
      predicate: vp,
      subject: nil,
      language: verb_token.language,
      span: span
    }

    # Determine function
    punct = List.last(tokens)
    function = if punct.pos_tag == :punct, do: infer_function(punct), else: :declarative

    %Sentence{
      function: function,
      structure: :simple,
      main_clause: clause,
      language: clause.language,
      span: span
    }
  end
end
