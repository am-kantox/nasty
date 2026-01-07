defmodule Nasty.Language.English.EntityRecognizer do
  @moduledoc """
  Rule-based Named Entity Recognition (NER) for English.

  This module provides English-specific configuration for the generic
  rule-based entity recognition algorithm. It implements the callbacks
  required by `Nasty.Semantic.EntityRecognition.RuleBased` and delegates
  the actual recognition logic to that generic module.

  ## Examples

      iex> tokens = tag_pos("John Smith lives in New York")
      iex> entities = EntityRecognizer.recognize(tokens)
      [
        %Entity{type: :person, text: "John Smith", ...},
        %Entity{type: :gpe, text: "New York", ...}
      ]
  """

  @behaviour Nasty.Semantic.EntityRecognition.RuleBased

  alias Nasty.AST.Token
  alias Nasty.Semantic.EntityRecognition.RuleBased

  # Callbacks for RuleBased behaviour

  @impl true
  def excluded_pos_tags, do: [:punct, :det, :adp, :verb, :aux]

  @impl true
  def classification_rules do
    [
      {:person, &has_title_prefix?/1},
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

  @impl true
  def default_classification(tokens) do
    cond do
      # Multi-word capitalized phrase - likely person or org
      length(tokens) >= 2 && RuleBased.all_capitalized?(tokens) ->
        if looks_like_person_name?(tokens), do: :person, else: :org

      # Single proper noun - could be anything, default to person
      length(tokens) == 1 ->
        :person

      true ->
        nil
    end
  end

  @doc """
  Recognizes named entities in a list of POS-tagged tokens.

  Returns a list of Entity structs.
  """
  @spec recognize([Token.t()]) :: [Nasty.AST.Semantic.Entity.t()]
  def recognize(tokens) do
    # Delegate to generic rule-based algorithm
    RuleBased.recognize(__MODULE__, tokens)
  end

  # English-specific pattern matching functions

  # Check if tokens have title prefix (Mr., Dr., etc.)
  defp has_title_prefix?({_text, [first | _rest]}) do
    String.downcase(first.text) in ~w(mr mrs ms dr prof sir)
  end

  defp has_title_prefix?(_), do: false

  # Check if text ends with location suffix
  defp has_location_suffix?({text, _tokens}) do
    String.ends_with?(String.downcase(text), [
      " city",
      " town",
      " village",
      " county",
      " state",
      " province",
      " country",
      " island",
      " mountain",
      " river",
      " lake"
    ])
  end

  # Check if text ends with organization suffix
  defp has_org_suffix?({text, _tokens}) do
    String.ends_with?(String.downcase(text), [
      " inc",
      " corp",
      " ltd",
      " llc",
      " co",
      " company",
      " corporation",
      " university",
      " college",
      " institute",
      " foundation",
      " association",
      " committee",
      " department"
    ])
  end

  # Heuristic: person names typically have 2-3 words
  defp looks_like_person_name?(tokens) do
    length(tokens) <= 3
  end

  # Lexicon of common person names (subset)
  defp person_name?(text) do
    lowercase = String.downcase(text)

    # Common first names
    first_names = ~w(
      john mary james patricia robert jennifer michael linda
      william elizabeth david barbara richard susan joseph jessica
      thomas sarah charles karen christopher nancy daniel betty
      matthew sandra anthony ashley mark donna paul michelle
      donald kimberly george emily kenneth lisa steven margaret
      edward amy brian laura ronald dorothy timothy deborah
      jason angela jeffrey helen gary sharon nicholas rachel
      eric rebecca stephen emma frank anna jonathan samantha
      scott kathleen brandon julie gregory carolyn adam heather
      harry martha jeremy diane arthur amy peter sophia
      henry grace albert olivia walter victoria fred emily
    )

    # Check if starts with common first name
    Enum.any?(first_names, fn name -> String.starts_with?(lowercase, name) end)
  end

  # Lexicon of common place names (subset)
  defp place_name?(text) do
    lowercase = String.downcase(text)

    # Major cities and countries
    places = ~w(
      london paris tokyo beijing moscow dubai singapore sydney
      mumbai toronto barcelona madrid amsterdam berlin rome
      new\ york los\ angeles chicago houston phoenix philadelphia
      san\ antonio san\ diego dallas san\ jose austin detroit
      united\ states america canada mexico brazil argentina
      china japan india russia germany france italy spain
      australia nigeria south\ africa egypt kenya ethiopia
      england scotland wales ireland california texas florida
      new\ york\ city san\ francisco washington boston seattle
    )

    lowercase in places
  end

  # Lexicon of common organization names (subset)
  defp organization_name?(text) do
    lowercase = String.downcase(text)

    orgs = ~w(
      google apple microsoft amazon facebook meta tesla
      walmart toyota samsung coca-cola disney nike intel
      ibm oracle netflix spotify uber twitter linkedin
      harvard mit stanford oxford cambridge yale princeton
      nasa who unesco world\ bank united\ nations
      google\ inc apple\ inc microsoft\ corporation
    )

    lowercase in orgs or
      Enum.any?(orgs, fn org -> String.starts_with?(lowercase, org) end)
  end
end
