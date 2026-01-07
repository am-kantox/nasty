defmodule Nasty.Language.English.CoreferenceConfig do
  @moduledoc """
  English-specific configuration for coreference resolution.

  Provides language-specific functions for:
  - Pronoun classification (gender, number)
  - Gender inference from names
  - Determiner classification
  - Plural markers

  These functions are passed as callbacks to the generic coreference resolver.
  """

  alias Nasty.AST.Token

  # Pronoun categories
  @male_pronouns ["he", "him", "his", "himself"]
  @female_pronouns ["she", "her", "hers", "herself"]
  @neutral_pronouns ["it", "its", "itself"]
  @plural_pronouns ["they", "them", "their", "theirs", "themselves"]

  @all_pronouns @male_pronouns ++ @female_pronouns ++ @neutral_pronouns ++ @plural_pronouns

  # Definite determiners
  @definite_determiners ["the", "this", "that", "these", "those"]

  @doc """
  Checks if a token is a pronoun.

  Returns true for personal, possessive, and reflexive pronouns.

  ## Examples

      iex> token = %Token{text: "he", pos_tag: :pron}
      iex> CoreferenceConfig.pronoun?(token)
      true

      iex> token = %Token{text: "cat", pos_tag: :noun}
      iex> CoreferenceConfig.pronoun?(token)
      false
  """
  @spec pronoun?(Token.t()) :: boolean()
  def pronoun?(%Token{pos_tag: pos, text: text}) do
    pos == :pron or String.downcase(text) in @all_pronouns
  end

  @doc """
  Classifies a pronoun by gender and number.

  Returns a tuple of {gender, number} where:
  - Gender: :male, :female, :neutral, :plural, or :unknown
  - Number: :singular or :plural

  ## Examples

      iex> CoreferenceConfig.classify_pronoun("he")
      {:male, :singular}

      iex> CoreferenceConfig.classify_pronoun("they")
      {:plural, :plural}

      iex> CoreferenceConfig.classify_pronoun("it")
      {:neutral, :singular}
  """
  @spec classify_pronoun(String.t()) :: {atom(), atom()}
  def classify_pronoun(text) do
    cond do
      text in @male_pronouns -> {:male, :singular}
      text in @female_pronouns -> {:female, :singular}
      text in @neutral_pronouns -> {:neutral, :singular}
      text in @plural_pronouns -> {:plural, :plural}
      true -> {:unknown, :unknown}
    end
  end

  @doc """
  Infers gender from a person's name or entity type.

  This is a simple heuristic-based approach. A production system would use
  a name database or external service for better accuracy.

  ## Parameters

    - `text` - The name or entity text
    - `entity_type` - The entity type (:person, :org, :gpe, etc.)

  ## Returns

  Gender atom: :male, :female, :neutral, or :unknown

  ## Examples

      iex> CoreferenceConfig.infer_person_gender("John Smith", :person)
      :male

      iex> CoreferenceConfig.infer_person_gender("Google", :org)
      :neutral
  """
  @spec infer_person_gender(String.t(), atom()) :: atom()
  def infer_person_gender(text, entity_type) do
    case entity_type do
      :person ->
        # Simple name-based heuristics (very basic)
        cond do
          String.contains?(text, ["Mr.", "John", "James", "Michael", "David", "Robert"]) ->
            :male

          String.contains?(text, ["Ms.", "Mrs.", "Mary", "Sarah", "Jennifer", "Lisa"]) ->
            :female

          true ->
            :unknown
        end

      # Non-person entities are neutral
      _ ->
        :neutral
    end
  end

  @doc """
  Checks if a determiner is definite.

  Definite determiners: the, this, that, these, those

  ## Examples

      iex> CoreferenceConfig.definite_determiner?("the")
      true

      iex> CoreferenceConfig.definite_determiner?("a")
      false
  """
  @spec definite_determiner?(String.t()) :: boolean()
  def definite_determiner?(text) do
    text in @definite_determiners
  end

  @doc """
  Checks if a text indicates plural form.

  Simple heuristic: words ending in 's' are likely plural.
  This is a basic check - a production system would use morphological analysis.

  ## Examples

      iex> CoreferenceConfig.plural_marker?("cats")
      true

      iex> CoreferenceConfig.plural_marker?("cat")
      false
  """
  @spec plural_marker?(String.t()) :: boolean()
  def plural_marker?(text) do
    String.ends_with?(text, "s")
  end

  @doc """
  Returns the complete language configuration map.

  This map contains all callback functions needed by the generic resolver.

  ## Examples

      iex> config = CoreferenceConfig.config()
      iex> config.pronoun?.(%Token{text: "he", pos_tag: :pron})
      true
  """
  @spec config() :: map()
  def config do
    %{
      pronoun?: &pronoun?/1,
      classify_pronoun: &classify_pronoun/1,
      infer_gender: &infer_person_gender/2,
      definite_determiner?: &definite_determiner?/1,
      plural_marker?: &plural_marker?/1
    }
  end
end
