defmodule Nasty.Semantic.EntityRecognition.RuleBased do
  @moduledoc """
  Language-agnostic rule-based Named Entity Recognition (NER).

  Provides a generic framework for rule-based entity recognition that can be
  configured with language-specific lexicons and patterns. The algorithm:

  1. Finds sequences of capitalized tokens (potential entities)
  2. Classifies each sequence using configurable rules
  3. Returns Entity structs with type, text, tokens, and span

  ## Usage

      defmodule MyLanguage.EntityRecognizer do
        @behaviour Nasty.Semantic.EntityRecognition.RuleBased

        @impl true
        def excluded_pos_tags, do: [:punct, :det, :adp, :verb, :aux]

        @impl true
        def classification_rules do
          [
            {:person, &has_person_title?/1},
            {:gpe, &has_location_suffix?/1},
            {:org, &has_org_suffix?/1}
          ]
        end

        @impl true
        def lexicon_matchers do
          %{
            person: &person_name?/1,
            gpe: &place_name?/1,
            org: &organization_name?/1
          }
        end
      end
  """

  alias Nasty.AST.{Node, Token}
  alias Nasty.AST.Semantic.Entity

  @doc """
  Callback for POS tags to exclude when finding entity sequences.
  """
  @callback excluded_pos_tags() :: [atom()]

  @doc """
  Callback for ordered classification rules.
  Returns a list of {type, predicate_function} tuples.
  Predicates receive {text, tokens} and return boolean.
  """
  @callback classification_rules() :: [{atom(), function()}]

  @doc """
  Callback for lexicon matchers (optional).
  Returns a map of entity_type => matcher_function.
  Matcher functions receive text and return boolean.
  """
  @callback lexicon_matchers() :: %{atom() => function()}

  @doc """
  Callback for default classification heuristics (optional).
  Receives tokens and returns entity type or nil.
  """
  @callback default_classification([Token.t()]) :: atom() | nil

  @optional_callbacks lexicon_matchers: 0, default_classification: 1

  @doc """
  Recognizes named entities in a list of POS-tagged tokens.

  Returns a list of Entity structs.
  """
  @spec recognize(module(), [Token.t()], keyword()) :: [Entity.t()]
  def recognize(impl, tokens, opts \\ []) do
    confidence = Keyword.get(opts, :confidence, 0.7)

    tokens
    |> find_proper_noun_sequences(impl)
    |> Enum.map(&classify_entity(impl, &1, confidence))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Finds sequences of consecutive capitalized tokens.

  Groups tokens that:
  - Are capitalized
  - Are not in excluded POS tags
  - Are consecutive

  Returns list of {text, tokens, span} tuples.
  """
  @spec find_proper_noun_sequences([Token.t()], module()) :: [
          {String.t(), [Token.t()], Node.span()}
        ]
  def find_proper_noun_sequences(tokens, impl) do
    excluded = MapSet.new(impl.excluded_pos_tags())

    tokens
    |> Enum.with_index()
    # Group by capitalized words not in excluded tags
    |> Enum.chunk_by(fn {token, _idx} ->
      capitalized?(token) && not MapSet.member?(excluded, token.pos_tag)
    end)
    |> Enum.filter(fn chunk ->
      case chunk do
        [{token, _} | _] ->
          capitalized?(token) && not MapSet.member?(excluded, token.pos_tag)

        _ ->
          false
      end
    end)
    |> Enum.map(fn chunk ->
      tokens = Enum.map(chunk, fn {token, _idx} -> token end)
      text = Enum.map_join(tokens, " ", & &1.text)

      first = hd(tokens)
      last = List.last(tokens)

      span =
        Node.make_span(
          first.span.start_pos,
          first.span.start_offset,
          last.span.end_pos,
          last.span.end_offset
        )

      {text, tokens, span}
    end)
  end

  @doc """
  Checks if a token is capitalized.
  """
  @spec capitalized?(Token.t()) :: boolean()
  def capitalized?(%Token{text: text}) do
    first_char = String.first(text)
    first_char == String.upcase(first_char) && first_char =~ ~r/[A-Z]/
  end

  @doc """
  Classifies an entity sequence using configured rules.
  """
  @spec classify_entity(module(), {String.t(), [Token.t()], Node.span()}, float()) ::
          Entity.t() | nil
  def classify_entity(impl, {text, tokens, span}, confidence) do
    type = determine_entity_type(impl, text, tokens)

    if type do
      Entity.new(type, text, tokens, span, confidence: confidence)
    else
      nil
    end
  end

  @doc """
  Determines entity type using lexicons, patterns, and heuristics.

  Order of precedence:
  1. Lexicon matchers (if provided)
  2. Classification rules
  3. Default classification (if provided)
  """
  @spec determine_entity_type(module(), String.t(), [Token.t()]) :: atom() | nil
  def determine_entity_type(impl, text, tokens) do
    # Try lexicon matchers first
    lexicon_type = check_lexicons(impl, text)

    if lexicon_type do
      lexicon_type
    else
      # Try classification rules
      rule_type = check_classification_rules(impl, text, tokens)

      if rule_type do
        rule_type
      else
        # Try default classification
        check_default_classification(impl, tokens)
      end
    end
  end

  @doc """
  Checks lexicon matchers for entity type.
  """
  @spec check_lexicons(module(), String.t()) :: atom() | nil
  def check_lexicons(impl, text) do
    if function_exported?(impl, :lexicon_matchers, 0) do
      matchers = impl.lexicon_matchers()

      Enum.find_value(matchers, fn {type, matcher} ->
        if matcher.(text), do: type, else: nil
      end)
    else
      nil
    end
  end

  @doc """
  Checks classification rules in order.
  """
  @spec check_classification_rules(module(), String.t(), [Token.t()]) :: atom() | nil
  def check_classification_rules(impl, text, tokens) do
    rules = impl.classification_rules()

    Enum.find_value(rules, fn {type, predicate} ->
      if predicate.({text, tokens}), do: type, else: nil
    end)
  end

  @doc """
  Checks default classification heuristics.
  """
  @spec check_default_classification(module(), [Token.t()]) :: atom() | nil
  def check_default_classification(impl, tokens) do
    if function_exported?(impl, :default_classification, 1) do
      impl.default_classification(tokens)
    else
      nil
    end
  end

  @doc """
  Checks if all tokens in a sequence are capitalized.
  """
  @spec all_capitalized?([Token.t()]) :: boolean()
  def all_capitalized?(tokens) do
    Enum.all?(tokens, fn token ->
      first_char = String.first(token.text)
      first_char == String.upcase(first_char)
    end)
  end
end
