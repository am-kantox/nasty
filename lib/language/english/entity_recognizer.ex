defmodule Nasty.Language.English.EntityRecognizer do
  @moduledoc """
  Basic rule-based Named Entity Recognition (NER) for English.

  Uses simple heuristics to identify entities:
  - Proper nouns (PROPN) as potential entities
  - Consecutive proper nouns as multi-word entities
  - Pattern matching for common entity indicators
  - Lexicon-based classification for known entities

  ## Approach

  This is a simplified, rule-based approach. Production NER systems typically use:
  - Machine learning models (CRF, LSTM, Transformers)
  - Large training corpora
  - Contextual embeddings

  ## Examples

      iex> tokens = tag_pos("John Smith lives in New York")
      iex> entities = EntityRecognizer.recognize(tokens)
      [
        %Entity{type: :person, text: "John Smith", ...},
        %Entity{type: :gpe, text: "New York", ...}
      ]
  """

  alias Nasty.AST.{Entity, Node, Token}

  @doc """
  Recognizes named entities in a list of POS-tagged tokens.

  Returns a list of Entity structs.
  """
  @spec recognize([Token.t()]) :: [Entity.t()]
  def recognize(tokens) do
    tokens
    |> find_proper_noun_sequences()
    |> Enum.map(&classify_entity/1)
    |> Enum.reject(&is_nil/1)
  end

  # Find sequences of consecutive capitalized words (potential entities)
  defp find_proper_noun_sequences(tokens) do
    tokens
    |> Enum.with_index()
    # Group by capitalized words (not just PROPN)
    |> Enum.chunk_by(fn {token, _idx} ->
      capitalized?(token) && token.pos_tag not in [:punct, :det, :adp, :verb, :aux]
    end)
    |> Enum.filter(fn chunk ->
      case chunk do
        [{token, _} | _] ->
          capitalized?(token) && token.pos_tag not in [:punct, :det, :adp, :verb, :aux]

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

  # Check if a token is capitalized
  defp capitalized?(%Token{text: text}) do
    first_char = String.first(text)
    first_char == String.upcase(first_char) && first_char =~ ~r/[A-Z]/
  end

  # Classify entity type based on heuristics
  defp classify_entity({text, tokens, span}) do
    type = determine_entity_type(text, tokens)

    if type do
      Entity.new(type, text, tokens, span, confidence: 0.7)
    else
      nil
    end
  end

  # Determine entity type using heuristics
  defp determine_entity_type(text, tokens) do
    cond do
      # Check known entity lexicons
      person_name?(text) ->
        :person

      place_name?(text) ->
        :gpe

      organization_name?(text) ->
        :org

      # Pattern-based heuristics
      has_title_prefix?(tokens) ->
        :person

      has_location_suffix?(text) ->
        :gpe

      has_org_suffix?(text) ->
        :org

      # Default heuristics based on word count and capitalization
      length(tokens) >= 2 && all_capitalized?(tokens) ->
        # Multi-word capitalized phrase - likely person or org
        if looks_like_person_name?(tokens), do: :person, else: :org

      length(tokens) == 1 ->
        # Single proper noun - could be anything, default to person
        :person

      true ->
        nil
    end
  end

  # Check if tokens have title prefix (Mr., Dr., etc.)
  defp has_title_prefix?([first | _rest]) do
    String.downcase(first.text) in ~w(mr mrs ms dr prof sir)
  end

  defp has_title_prefix?(_), do: false

  # Check if text ends with location suffix
  defp has_location_suffix?(text) do
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
  defp has_org_suffix?(text) do
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

  # Check if all tokens are capitalized
  defp all_capitalized?(tokens) do
    Enum.all?(tokens, fn token ->
      first_char = String.first(token.text)
      first_char == String.upcase(first_char)
    end)
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
