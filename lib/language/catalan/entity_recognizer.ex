defmodule Nasty.Language.Catalan.EntityRecognizer do
  @moduledoc """
  Recognizes named entities in Catalan text.

  Uses rule-based patterns to identify:
  - PERSON: names (Joan Garcia, Maria López)
  - LOCATION: cities, regions (Barcelona, Catalunya, València)
  - ORGANIZATION: companies, institutions (Banc de Catalunya, FC Barcelona)
  - DATE: temporal expressions (dilluns, 15 de gener, 2024)
  - MONEY: currency amounts (100 euros, 25€)
  - PERCENT: percentages (25%, 3,5 per cent)

  ## Catalan-Specific Features

  - Catalan name and place lexicons
  - Catalan titles (Sr., Sra., Dr., Dra., Don, Donya)
  - Catalan date formats (15 de gener de 2024)
  - Euro currency symbols (€)
  - Catalan organizational patterns (S.A., S.L.)
  """

  alias Nasty.AST.{Node, Token}
  alias Nasty.AST.Semantic.Entity

  @spec recognize([Token.t()], keyword()) :: {:ok, [Entity.t()]} | {:error, term()}
  def recognize(tokens, opts \\ []) when is_list(tokens) do
    entities =
      []
      |> recognize_persons(tokens)
      |> recognize_locations(tokens)
      |> recognize_organizations(tokens)
      |> recognize_dates(tokens)
      |> recognize_money(tokens)
      |> recognize_percents(tokens)

    types_filter = Keyword.get(opts, :types, nil)
    min_conf = Keyword.get(opts, :min_confidence, 0.5)

    filtered =
      entities
      |> Enum.filter(fn e -> e.confidence >= min_conf end)
      |> Enum.filter(fn e -> types_filter == nil or e.type in types_filter end)

    {:ok, filtered}
  end

  defp recognize_persons(entities, tokens) do
    catalan_titles = ~w(sr sra dr dra don donya)
    _common_first = ~w(joan maria josep anna pere marc laura david carles núria)

    tokens
    |> Enum.with_index()
    |> Enum.reduce(entities, fn {token, idx}, acc ->
      cond do
        is_capitalized?(token) and has_following_capitalized?(tokens, idx) ->
          case get_person_span(tokens, idx) do
            {start_idx, end_idx, conf} when conf > 0.5 ->
              entity = create_entity(:PERSON, tokens, start_idx, end_idx, conf)
              [entity | acc]

            _ ->
              acc
          end

        String.downcase(token.text) in catalan_titles ->
          case get_name_after_title(tokens, idx) do
            {start_idx, end_idx} ->
              entity = create_entity(:PERSON, tokens, start_idx, end_idx, 0.9)
              [entity | acc]

            nil ->
              acc
          end

        true ->
          acc
      end
    end)
  end

  defp recognize_locations(entities, tokens) do
    catalan_places = ~w(barcelona catalunya valència girona tarragona lleida andorra madrid)

    tokens
    |> Enum.with_index()
    |> Enum.reduce(entities, fn {token, idx}, acc ->
      if String.downcase(token.text) in catalan_places or
           (is_capitalized?(token) and token.pos_tag == :propn) do
        entity = create_entity(:LOCATION, tokens, idx, idx, 0.7)
        [entity | acc]
      else
        acc
      end
    end)
  end

  defp recognize_organizations(entities, tokens) do
    org_indicators = ~w(banc universitat hospital ajuntament govern)

    tokens
    |> Enum.with_index()
    |> Enum.reduce(entities, fn {token, idx}, acc ->
      if String.downcase(token.text) in org_indicators do
        case get_org_span(tokens, idx) do
          {start_idx, end_idx} ->
            entity = create_entity(:ORGANIZATION, tokens, start_idx, end_idx, 0.8)
            [entity | acc]

          nil ->
            acc
        end
      else
        acc
      end
    end)
  end

  defp recognize_dates(entities, tokens) do
    months = ~w(gener febrer març abril maig juny juliol agost setembre octubre novembre desembre)
    days = ~w(dilluns dimarts dimecres dijous divendres dissabte diumenge)

    tokens
    |> Enum.with_index()
    |> Enum.reduce(entities, fn {token, idx}, acc ->
      text_lower = String.downcase(token.text)

      cond do
        text_lower in months or text_lower in days ->
          entity = create_entity(:DATE, tokens, idx, idx, 0.9)
          [entity | acc]

        token.pos_tag == :num and has_date_context?(tokens, idx) ->
          entity = create_entity(:DATE, tokens, idx, idx, 0.7)
          [entity | acc]

        true ->
          acc
      end
    end)
  end

  defp recognize_money(entities, tokens) do
    currency = ~w(euro euros € dòlar dòlars $)

    tokens
    |> Enum.with_index()
    |> Enum.reduce(entities, fn {token, idx}, acc ->
      cond do
        token.pos_tag == :num and has_currency_after?(tokens, idx, currency) ->
          entity = create_entity(:MONEY, tokens, idx, idx + 1, 0.9)
          [entity | acc]

        String.downcase(token.text) in currency and has_number_before?(tokens, idx) ->
          entity = create_entity(:MONEY, tokens, idx - 1, idx, 0.9)
          [entity | acc]

        true ->
          acc
      end
    end)
  end

  defp recognize_percents(entities, tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.reduce(entities, fn {token, idx}, acc ->
      if token.text == "%" or String.contains?(String.downcase(token.text), "per cent") do
        if has_number_before?(tokens, idx) do
          entity = create_entity(:PERCENT, tokens, idx - 1, idx, 0.95)
          [entity | acc]
        else
          acc
        end
      else
        acc
      end
    end)
  end

  ## Helpers

  defp is_capitalized?(%Token{text: text}) do
    first = String.first(text)
    first == String.upcase(first) and String.match?(first, ~r/\p{Lu}/u)
  end

  defp has_following_capitalized?(tokens, idx) when idx + 1 < length(tokens) do
    next = Enum.at(tokens, idx + 1)
    (next && is_capitalized?(next)) and next.pos_tag in [:noun, :propn]
  end

  defp has_following_capitalized?(_, _), do: false

  defp get_person_span(tokens, start_idx) do
    end_idx =
      start_idx..(length(tokens) - 1)
      |> Enum.take_while(fn idx ->
        token = Enum.at(tokens, idx)
        is_capitalized?(token) and token.pos_tag in [:noun, :propn]
      end)
      |> List.last()

    if end_idx && end_idx > start_idx do
      {start_idx, end_idx, 0.7}
    else
      {start_idx, start_idx, 0.5}
    end
  end

  defp get_name_after_title(tokens, title_idx) when title_idx + 1 < length(tokens) do
    next_token = Enum.at(tokens, title_idx + 1)

    if next_token && is_capitalized?(next_token) do
      case get_person_span(tokens, title_idx + 1) do
        {_, end_idx, _} -> {title_idx + 1, end_idx}
        _ -> nil
      end
    else
      nil
    end
  end

  defp get_name_after_title(_, _), do: nil

  defp get_org_span(tokens, start_idx) do
    end_idx =
      (start_idx + 1)..min(start_idx + 5, length(tokens) - 1)
      |> Enum.take_while(fn idx ->
        token = Enum.at(tokens, idx)
        token && (is_capitalized?(token) or token.text in ["de", "del", "la", "el"])
      end)
      |> List.last()

    if end_idx && end_idx > start_idx do
      {start_idx, end_idx}
    else
      {start_idx, start_idx}
    end
  end

  defp has_date_context?(tokens, idx) do
    prev = if idx > 0, do: Enum.at(tokens, idx - 1)
    next = if idx + 1 < length(tokens), do: Enum.at(tokens, idx + 1)

    (prev && String.downcase(prev.text) == "de") or
      (next && String.downcase(next.text) in ["de", "gener", "febrer", "març"])
  end

  defp has_currency_after?(tokens, idx, currency) when idx + 1 < length(tokens) do
    next = Enum.at(tokens, idx + 1)
    next && String.downcase(next.text) in currency
  end

  defp has_currency_after?(_, _, _), do: false

  defp has_number_before?(tokens, idx) when idx > 0 do
    prev = Enum.at(tokens, idx - 1)
    prev && prev.pos_tag == :num
  end

  defp has_number_before?(_, _), do: false

  defp create_entity(type, tokens, start_idx, end_idx, confidence) do
    entity_tokens = Enum.slice(tokens, start_idx..end_idx)
    text = Enum.map_join(entity_tokens, " ", & &1.text)

    first_token = hd(entity_tokens)
    last_token = List.last(entity_tokens)

    span =
      Node.make_span(
        first_token.span.start_pos,
        first_token.span.start_offset,
        last_token.span.end_pos,
        last_token.span.end_offset
      )

    # Map Catalan entity types to standard NER types
    entity_type =
      case type do
        :PERSON -> :person
        :LOCATION -> :loc
        :ORGANIZATION -> :org
        :DATE -> :date
        :MONEY -> :money
        :PERCENT -> :percent
        _ -> :misc
      end

    Entity.new(
      entity_type,
      text,
      entity_tokens,
      span,
      confidence: confidence
    )
  end
end
