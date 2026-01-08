defmodule Nasty.Language.English.EntityRecognizer do
  @moduledoc """
  Named Entity Recognition (NER) for English.

  Supports multiple approaches:
  - Rule-based NER (default)
  - CRF-based NER (statistical sequence labeling)

  ## Examples

      # Rule-based (default)
      iex> tokens = tag_pos("John Smith lives in New York")
      iex> entities = EntityRecognizer.recognize(tokens)
      [
        %Entity{type: :person, text: "John Smith", ...},
        %Entity{type: :gpe, text: "New York", ...}
      ]

      # CRF-based
      iex> entities = EntityRecognizer.recognize(tokens, model: :crf)
      [
        %Entity{type: :person, text: "John Smith", ...},
        %Entity{type: :gpe, text: "New York", ...}
      ]
  """

  @behaviour Nasty.Semantic.EntityRecognition.RuleBased

  alias Nasty.AST.{Semantic.Entity, Token}
  alias Nasty.Semantic.EntityRecognition.RuleBased
  alias Nasty.Statistics.{ModelLoader, SequenceLabeling.CRF}

  require Logger

  # Callbacks for RuleBased behaviour

  @impl true
  def excluded_pos_tags, do: [:punct, :det, :adp, :verb, :aux]

  @impl true
  def classification_rules do
    [
      {:person, &has_title_prefix?/1},
      {:gpe, &has_location_suffix?/1},
      {:org, &has_org_suffix?/1},
      {:date, &is_date_pattern?/1},
      {:time, &is_time_pattern?/1},
      {:money, &is_money_pattern?/1}
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

  ## Options

    - `:model` - Model type: `:rule_based` (default) or `:crf`
    - `:crf_model` - Trained CRF model (optional, will load from registry if not provided)

  ## Returns

    - List of Entity structs
  """
  @spec recognize([Token.t()], keyword()) :: [Entity.t()]
  def recognize(tokens, opts \\ []) do
    model_type = Keyword.get(opts, :model, :rule_based)

    case model_type do
      :rule_based ->
        recognize_rule_based(tokens)

      :crf ->
        recognize_crf(tokens, opts)

      _ ->
        # Unknown model type, fallback to rule-based
        Logger.warning("Unknown NER model type: #{inspect(model_type)}, using rule-based")
        recognize_rule_based(tokens)
    end
  end

  @doc """
  Rule-based entity recognition (original implementation).
  """
  @spec recognize_rule_based([Token.t()]) :: [Entity.t()]
  def recognize_rule_based(tokens) do
    # Delegate to generic rule-based algorithm
    RuleBased.recognize(__MODULE__, tokens)
  end

  @doc """
  CRF-based entity recognition using statistical sequence labeling.

  If no model is provided via `:crf_model` option, attempts to load
  the latest NER CRF model from the registry. Falls back to rule-based
  recognition if no model is available.
  """
  @spec recognize_crf([Token.t()], keyword()) :: [Entity.t()]
  def recognize_crf(tokens, opts) do
    crf_model =
      case Keyword.get(opts, :crf_model) do
        nil ->
          # Try to load from registry
          case ModelLoader.load_latest(:en, :ner_crf) do
            {:ok, model} ->
              Logger.debug("Loaded CRF NER model from registry")
              model

            {:error, :not_found} ->
              Logger.warning(
                "No CRF NER model found. Falling back to rule-based recognition. " <>
                  "Train a model using: mix nasty.train.crf --task ner"
              )

              nil
          end

        model ->
          model
      end

    case crf_model do
      nil ->
        # Fallback to rule-based
        recognize_rule_based(tokens)

      model ->
        case CRF.predict(model, tokens, []) do
          {:ok, labels} ->
            # Convert CRF labels to Entity structs
            labels_to_entities(tokens, labels)

            # [TODO] make `CRF.predict/3` to return errors somewhen and uncomment that
            # {:error, reason} ->
            #   Logger.warning(
            #     "CRF prediction failed: #{inspect(reason)}, falling back to rule-based"
            #   )

            #   recognize_rule_based(tokens)
        end
    end
  end

  # Convert CRF labels to Entity structs
  defp labels_to_entities(tokens, labels) do
    tokens
    |> Enum.zip(labels)
    |> Enum.chunk_by(fn {_token, label} -> label end)
    |> Enum.filter(fn chunk ->
      {_token, label} = hd(chunk)
      label != :none and label != :o
    end)
    |> Enum.map(fn chunk ->
      entity_tokens = Enum.map(chunk, fn {token, _label} -> token end)
      {_first_token, label} = hd(chunk)

      first = hd(entity_tokens)
      last = List.last(entity_tokens)

      text = Enum.map_join(entity_tokens, " ", & &1.text)

      span =
        if first.span && last.span do
          Nasty.AST.Node.make_span(
            first.span.start_pos,
            first.span.start_offset,
            last.span.end_pos,
            last.span.end_offset
          )
        else
          nil
        end

      %Entity{
        type: label,
        text: text,
        tokens: entity_tokens,
        span: span,
        confidence: 0.85
      }
    end)
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

  # Check if text matches date pattern
  defp is_date_pattern?({text, tokens}) do
    # Patterns: "January 5", "Jan 5", "5 January", "2026", "5/1/2026"
    cond do
      # Month names
      has_month_name?(text) ->
        true

      # Year (4 digits)
      Regex.match?(~r/^\d{4}$/, text) ->
        true

      # Date with slashes or dashes
      Regex.match?(~r/^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}$/, text) ->
        true

      # Day + month or month + day (e.g., "5 January", "January 5")
      length(tokens) == 2 and
          (has_month_name?(hd(tokens).text) or has_month_name?(List.last(tokens).text)) ->
        true

      true ->
        false
    end
  end

  # Check if text matches time pattern
  defp is_time_pattern?({text, _tokens}) do
    # Patterns: "3:00", "3:00 PM", "15:30", "noon", "midnight"
    text_lower = String.downcase(text)

    cond do
      # Time words
      text_lower in ~w(noon midnight morning afternoon evening night) ->
        true

      # HH:MM format
      Regex.match?(~r/^\d{1,2}:\d{2}(:\d{2})?$/, text) ->
        true

      # HH:MM AM/PM format (handled as multi-token)
      Regex.match?(~r/\d{1,2}:\d{2}\s*(am|pm|AM|PM)/, text) ->
        true

      true ->
        false
    end
  end

  # Check if text matches money pattern
  defp is_money_pattern?({text, tokens}) do
    # Patterns: "$100", "€50", "100 dollars", "fifty euros"
    text_lower = String.downcase(text)

    cond do
      # Currency symbols at start
      Regex.match?(~r/^[\$€£¥₹₽¢]/, text) ->
        true

      # Currency words at end
      Regex.match?(~r/(dollar|euro|pound|yen|cent|rupee|ruble|yuan)s?$/, text_lower) ->
        true

      # Number followed by currency word
      length(tokens) >= 2 and Regex.match?(~r/^\d+/, hd(tokens).text) and
          currency_word?(List.last(tokens).text) ->
        true

      true ->
        false
    end
  end

  # Helper: check if text contains a month name
  defp has_month_name?(text) do
    text_lower = String.downcase(text)

    months = ~w(
      january february march april may june july august
      september october november december
      jan feb mar apr jun jul aug sep sept oct nov dec
    )

    Enum.any?(months, fn month -> String.contains?(text_lower, month) end)
  end

  # Helper: check if text is a currency word
  defp currency_word?(text) do
    text_lower = String.downcase(text)

    text_lower in ~w(
      dollar dollars euro euros pound pounds sterling
      yen yuan rupee rupees ruble rubles cent cents
    )
  end
end
