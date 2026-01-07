defmodule Nasty.Semantic.SRL.AdjunctClassifier do
  @moduledoc """
  Generic classification of adjunct roles (location, time, manner, instrument, etc.)

  Adjuncts are optional modifiers that provide additional context about the action.
  This module classifies adverbials (adverbs and prepositional phrases) into semantic roles.
  """

  alias Nasty.AST.{NounPhrase, PrepositionalPhrase, Token, VerbPhrase}
  alias Nasty.AST.Semantic.Role

  @typedoc """
  Language configuration for adjunct classification.

  Required callbacks:
  - `temporal_adverb?/1` - Check if adverb indicates time (e.g., "yesterday", "now")
  - `preposition_role_map/0` - Map prepositions to semantic roles
  """
  @type language_config :: %{
          temporal_adverb?: (String.t() -> boolean()),
          preposition_role_map: (%{} -> map())
        }

  @doc """
  Classifies adverbials from a clause into semantic roles.

  Extracts adjuncts from VP adverbials and returns a list of semantic roles.
  """
  @spec classify_adverbials(Clause.t(), language_config()) :: [Role.t()]
  def classify_adverbials(clause, config)

  def classify_adverbials(
        %Nasty.AST.Clause{predicate: %VerbPhrase{adverbials: [_ | _] = adverbials}},
        config
      ) do
    Enum.flat_map(adverbials, fn adv ->
      classify_adverbial(adv, config)
    end)
  end

  def classify_adverbials(_, _config), do: []

  # Classify a single adverbial element
  defp classify_adverbial(%Token{} = token, config) do
    classify_adverb(token, config)
  end

  defp classify_adverbial(%PrepositionalPhrase{} = pp, config) do
    classify_pp(pp, config)
  end

  defp classify_adverbial(_other, _config), do: []

  # Classify an adverb token
  defp classify_adverb(%Token{text: text} = token, config) do
    temporal? = config.temporal_adverb?

    role_type =
      if temporal?.(text) do
        :time
      else
        :manner
      end

    [Role.new(role_type, text, token.span)]
  end

  # Classify a prepositional phrase
  defp classify_pp(%PrepositionalPhrase{head: prep} = pp, config) do
    prep_role_map = config.preposition_role_map.()
    prep_text = String.downcase(prep.text)

    role_type = Map.get(prep_role_map, prep_text, :location)

    text = extract_pp_text(pp)
    [Role.new(role_type, text, pp.span)]
  end

  # Extract text from prepositional phrase
  defp extract_pp_text(%PrepositionalPhrase{head: prep, object: obj}) do
    obj_text = extract_text(obj)
    "#{prep.text} #{obj_text}"
  end

  # Extract text from various phrase types
  defp extract_text(%NounPhrase{} = np) do
    tokens =
      [
        np.determiner,
        np.modifiers,
        [np.head],
        np.post_modifiers
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Enum.map_join(tokens, " ", fn
      %Token{text: text} -> text
      phrase -> extract_text(phrase)
    end)
  end

  defp extract_text(%Token{text: text}), do: text

  defp extract_text(_), do: ""
end
