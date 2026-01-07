defmodule Nasty.Semantic.Coreference.MentionDetector do
  @moduledoc """
  Generic mention detection for coreference resolution.

  Extracts three types of mentions from documents:
  1. Pronouns - personal, possessive, reflexive
  2. Proper names - from entity recognition
  3. Definite noun phrases - determiners like "the", "this", "that"

  The detector is language-agnostic and accepts callbacks for language-specific
  classification (pronoun types, gender inference, etc.).
  """

  alias Nasty.AST.{
    Clause,
    Document,
    NounPhrase,
    Sentence,
    Token
  }

  alias Nasty.AST.Semantic.{Entity, Mention}
  alias Nasty.Language.English.EntityRecognizer

  @type language_config :: %{
          pronoun?: (Token.t() -> boolean()),
          classify_pronoun: (String.t() -> {atom(), atom()}),
          infer_gender: (String.t(), atom() -> atom()),
          definite_determiner?: (String.t() -> boolean()),
          plural_marker?: (String.t() -> boolean())
        }

  @doc """
  Extracts all mentions from a document.

  ## Parameters

    - `document` - Document AST to extract mentions from
    - `config` - Language-specific configuration with callback functions
      - `:pronoun?` - Function to check if token is a pronoun
      - `:classify_pronoun` - Function to get pronoun gender/number
      - `:infer_gender` - Function to infer gender from name/entity type
      - `:definite_determiner?` - Function to check if text is definite determiner
      - `:plural_marker?` - Function to check if text indicates plural

  ## Returns

  List of Mention structs with position, type, and agreement features.

  ## Examples

      iex> config = %{
      ...>   pronoun?: &EnglishConfig.pronoun?/1,
      ...>   classify_pronoun: &EnglishConfig.classify_pronoun/1,
      ...>   ...
      ...> }
      iex> mentions = MentionDetector.extract_mentions(document, config)
      [%Mention{text: "John", type: :proper_name}, ...]
  """
  @spec extract_mentions(Document.t(), language_config()) :: [Mention.t()]
  def extract_mentions(%Document{paragraphs: paragraphs}, config) do
    paragraphs
    |> Enum.flat_map(fn para -> para.sentences end)
    |> Enum.with_index()
    |> Enum.flat_map(fn {sentence, sent_idx} ->
      extract_mentions_from_sentence(sentence, sent_idx, config)
    end)
  end

  @doc """
  Extracts mentions from a single sentence.

  Returns pronoun, entity, and definite NP mentions.
  """
  @spec extract_mentions_from_sentence(Sentence.t(), non_neg_integer(), language_config()) :: [
          Mention.t()
        ]
  def extract_mentions_from_sentence(sentence, sent_idx, config) do
    # Get all tokens from clauses
    tokens =
      sentence
      |> Sentence.all_clauses()
      |> Enum.flat_map(&extract_tokens_from_clause/1)
      |> Enum.with_index()

    # Extract pronoun mentions
    pronoun_mentions =
      tokens
      |> Enum.filter(fn {token, _idx} -> config.pronoun?.(token) end)
      |> Enum.map(fn {token, tok_idx} ->
        create_pronoun_mention(token, sent_idx, tok_idx, config)
      end)

    # Extract proper name mentions (from entities)
    entity_mentions = extract_entity_mentions(sentence, sent_idx, config)

    # Extract definite NP mentions
    definite_np_mentions = extract_definite_np_mentions(sentence, sent_idx, config)

    pronoun_mentions ++ entity_mentions ++ definite_np_mentions
  end

  @doc """
  Extracts all tokens from a clause.

  Recursively extracts tokens from subject NP and predicate VP.
  """
  @spec extract_tokens_from_clause(Clause.t()) :: [Token.t()]
  def extract_tokens_from_clause(%Clause{subject: subject, predicate: predicate}) do
    subject_tokens = if subject, do: extract_tokens_from_np(subject), else: []
    predicate_tokens = extract_tokens_from_vp(predicate)
    subject_tokens ++ predicate_tokens
  end

  @doc """
  Extracts tokens from a noun phrase.

  Includes determiner, modifiers, and head.
  """
  @spec extract_tokens_from_np(NounPhrase.t()) :: [Token.t()]
  def extract_tokens_from_np(%NounPhrase{} = np) do
    [
      if(np.determiner, do: [np.determiner], else: []),
      np.modifiers,
      [np.head]
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Extracts tokens from a verb phrase.

  Includes auxiliaries and main verb head.
  """
  @spec extract_tokens_from_vp(map()) :: [Token.t()]
  def extract_tokens_from_vp(%{auxiliaries: aux, head: head}) do
    aux ++ [head]
  end

  def extract_tokens_from_vp(_), do: []

  ## Private Functions - Mention Creation

  # Create a pronoun mention
  defp create_pronoun_mention(token, sent_idx, tok_idx, config) do
    text_lower = String.downcase(token.text)
    {gender, number} = config.classify_pronoun.(text_lower)

    Mention.new(
      token.text,
      :pronoun,
      sent_idx,
      tok_idx,
      token.span,
      tokens: [token],
      gender: gender,
      number: number
    )
  end

  # Extract entity mentions (proper names)
  defp extract_entity_mentions(sentence, sent_idx, config) do
    # Get tokens for entity recognition
    tokens =
      sentence
      |> Sentence.all_clauses()
      |> Enum.flat_map(&extract_tokens_from_clause/1)

    # Run entity recognizer
    entities = EntityRecognizer.recognize(tokens)

    # Convert entities to mentions
    entities
    |> Enum.with_index()
    |> Enum.map(fn {entity, idx} ->
      {gender, number} = infer_entity_attributes(entity, config)

      Mention.new(
        entity.text,
        :proper_name,
        sent_idx,
        idx,
        entity.span,
        tokens: entity.tokens,
        gender: gender,
        number: number,
        entity_type: entity.type
      )
    end)
  end

  # Infer gender/number from entity
  defp infer_entity_attributes(%Entity{type: type, text: text}, config) do
    gender = config.infer_gender.(text, type)

    # Simple heuristic: check for "and" to detect plural
    number = if String.contains?(text, " and "), do: :plural, else: :singular

    {gender, number}
  end

  # Extract definite NP mentions
  defp extract_definite_np_mentions(sentence, sent_idx, config) do
    sentence
    |> Sentence.all_clauses()
    |> Enum.flat_map(fn clause ->
      extract_definite_nps_from_clause(clause, sent_idx, config)
    end)
  end

  defp extract_definite_nps_from_clause(%Clause{subject: subject}, sent_idx, config) do
    if subject && definite_np?(subject, config) do
      tokens = extract_tokens_from_np(subject)

      [
        Mention.new(
          extract_np_text(subject),
          :definite_np,
          sent_idx,
          0,
          subject.span,
          tokens: tokens,
          phrase: subject,
          gender: :unknown,
          number: if(plural_np?(subject, config), do: :plural, else: :singular)
        )
      ]
    else
      []
    end
  end

  # Check if NP is definite
  defp definite_np?(%NounPhrase{determiner: det}, config) do
    det && config.definite_determiner?.(String.downcase(det.text))
  end

  # Check if NP is plural
  defp plural_np?(%NounPhrase{head: head}, config) do
    head.pos_tag == :noun && config.plural_marker?.(head.text)
  end

  # Extract text from NP
  defp extract_np_text(%NounPhrase{} = np) do
    tokens = extract_tokens_from_np(np)
    Enum.map_join(tokens, " ", & &1.text)
  end
end
