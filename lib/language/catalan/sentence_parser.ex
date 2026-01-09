defmodule Nasty.Language.Catalan.SentenceParser do
  @moduledoc """
  Sentence and clause parser for Catalan.

  Builds Clause and Sentence structures from phrases with Catalan-specific patterns.

  ##  Catalan-Specific Features

  - Flexible word order: SVO default, but VSO and VOS common
  - Pro-drop: subject pronouns often omitted
  - Subordination: que, perquè, quan, si, encara, mentre
  """

  alias Nasty.AST.{Clause, Node, Sentence, Token}
  alias Nasty.Language.Catalan.PhraseParser

  require Logger

  @spec parse_sentences([Token.t()], keyword()) :: {:ok, [Sentence.t()]} | {:error, term()}
  def parse_sentences(tokens, opts \\ []) do
    model_type = Keyword.get(opts, :model, :rule_based)

    case model_type do
      :rule_based ->
        parse_sentences_rule_based(tokens)

      _ ->
        Logger.warning("Unknown parser model type: #{inspect(model_type)}, using rule-based")
        parse_sentences_rule_based(tokens)
    end
  end

  def parse_sentences_rule_based(tokens) do
    sentence_groups = split_sentences(tokens)

    sentences =
      sentence_groups
      |> Enum.map(&parse_sentence/1)
      |> Enum.reject(&is_nil/1)

    {:ok, sentences}
  end

  def parse_sentence([]), do: nil

  def parse_sentence(tokens) do
    {sentence_tokens, punct} = strip_trailing_punct(tokens)

    if Enum.empty?(sentence_tokens) do
      nil
    else
      case parse_clause(sentence_tokens) do
        {:ok, clauses} when is_list(clauses) ->
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

        {:ok, clause} when is_struct(clause, Clause) ->
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
            structure: :simple,
            main_clause: clause,
            language: clause.language,
            span: span
          }

        :error ->
          create_fallback_sentence(tokens)
      end
    end
  end

  def parse_clause([_ | _] = tokens) do
    case get_subordinator(tokens, 0) do
      {subord_token, rest_pos} ->
        case parse_simple_clause(Enum.drop(tokens, rest_pos)) do
          {:ok, clause} ->
            {:ok, %{clause | type: :subordinate, subordinator: subord_token}}

          :error ->
            parse_simple_clause(tokens)
        end

      nil ->
        case find_coordinating_conj(tokens) do
          {conj_pos, _conj_token} ->
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

  defp parse_simple_clause(tokens) do
    case find_verb_position(tokens) do
      nil ->
        :error

      verb_pos ->
        {subject, predicate} = split_at_verb(tokens, verb_pos)

        case PhraseParser.parse_verb_phrase(tokens, verb_pos) do
          {:ok, vp, _new_pos} ->
            subject_np =
              if subject != [] do
                case PhraseParser.parse_noun_phrase(subject, 0) do
                  {:ok, np, _} -> np
                  :error -> nil
                end
              else
                nil
              end

            first_token = if subject != [], do: hd(subject), else: hd(predicate)
            last_token = List.last(tokens)

            span =
              Node.make_span(
                first_token.span.start_pos,
                first_token.span.start_offset,
                last_token.span.end_pos,
                last_token.span.end_offset
              )

            language = if subject_np, do: subject_np.language, else: vp.language

            clause = %Clause{
              type: :main,
              subject: subject_np,
              predicate: vp,
              language: language,
              span: span
            }

            {:ok, clause}

          :error ->
            :error
        end
    end
  end

  ## Helpers

  defp split_sentences(tokens) do
    split_sentences_acc(tokens, [], [])
  end

  defp split_sentences_acc([%Token{pos_tag: :punct, text: text} = token | rest], current, acc)
       when text in [".", "!", "?", "...", "…"] do
    sentence = Enum.reverse([token | current])
    split_sentences_acc(rest, [], [sentence | acc])
  end

  defp split_sentences_acc([token | rest], current, acc) do
    split_sentences_acc(rest, [token | current], acc)
  end

  defp split_sentences_acc([], [], acc), do: Enum.reverse(acc)
  defp split_sentences_acc([], current, acc), do: Enum.reverse([Enum.reverse(current) | acc])

  defp strip_trailing_punct(tokens) do
    case List.last(tokens) do
      %Token{pos_tag: :punct} = punct ->
        {Enum.slice(tokens, 0..-2//1), punct}

      _ ->
        {tokens, nil}
    end
  end

  defp infer_function(nil), do: :declarative
  defp infer_function(%Token{text: "?"}), do: :interrogative
  defp infer_function(%Token{text: "!"}), do: :exclamative
  defp infer_function(_), do: :declarative

  defp get_subordinator(tokens, pos) when pos < length(tokens) do
    subordinators = ~w(que perquè quan on si encara mentre així doncs ja)

    case Enum.at(tokens, pos) do
      %Token{pos_tag: :sconj, text: text} = token ->
        if text in subordinators do
          {token, pos + 1}
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp get_subordinator(_, _), do: nil

  defp find_coordinating_conj(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.find(fn {token, _idx} -> token.pos_tag == :cconj end)
    |> case do
      {token, idx} -> {idx, token}
      nil -> nil
    end
  end

  defp find_verb_position(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.find(fn {token, _idx} -> token.pos_tag in [:verb, :aux] end)
    |> case do
      {_token, idx} -> idx
      nil -> nil
    end
  end

  defp split_at_verb(tokens, verb_pos) do
    subject = Enum.slice(tokens, 0, verb_pos)
    predicate = Enum.slice(tokens, verb_pos..-1//1)
    {subject, predicate}
  end

  defp create_fallback_sentence(tokens) do
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
      function: :declarative,
      structure: :fragment,
      main_clause: nil,
      language: first_token.language,
      span: span
    }
  end
end
