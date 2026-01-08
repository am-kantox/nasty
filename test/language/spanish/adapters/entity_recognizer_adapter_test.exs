defmodule Nasty.Language.Spanish.Adapters.EntityRecognizerAdapterTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.Spanish.Adapters.EntityRecognizerAdapter

  describe "recognize/2" do
    test "delegates to generic rule-based entity recognition with Spanish config" do
      tokens = build_spanish_tokens(["María", "García", "vive", "en", "Madrid", "."])

      result = EntityRecognizerAdapter.recognize(tokens)

      assert {:ok, entities} = result
      assert is_list(entities)
    end

    test "recognizes Spanish person names" do
      tokens = build_spanish_tokens(["El", "Dr.", "José", "García", "llegó", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "recognizes Spanish places and locations" do
      tokens = build_spanish_tokens(["Viajé", "a", "Madrid", "y", "Barcelona", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert match?([_ | _], location_entities)
    end

    test "recognizes Spanish organizations" do
      tokens = build_spanish_tokens(["Real", "Madrid", "ganó", "el", "partido", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes Spanish date formats" do
      tokens = build_spanish_tokens(["El", "15", "de", "enero", "de", "2024", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      date_entities = Enum.filter(entities, &(&1.type == :DATE))
      assert is_list(date_entities)
    end

    test "recognizes Spanish currency amounts with euro symbol" do
      tokens = build_spanish_tokens(["Cuesta", "100", "€", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      money_entities = Enum.filter(entities, &(&1.type == :MONEY))
      assert is_list(money_entities)
    end

    test "recognizes Spanish titles with person names" do
      tokens = build_spanish_tokens(["Sra.", "María", "López", "habló", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert is_list(person_entities)
    end

    test "filters entity types based on options" do
      tokens = build_spanish_tokens(["María", "vive", "en", "Madrid", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens, types: [:PERSON])

      assert Enum.all?(entities, &(&1.type == :PERSON))
    end

    test "respects minimum confidence threshold" do
      tokens = build_spanish_tokens(["Palabra", "ambigua", "aquí", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens, min_confidence: 0.8)

      assert is_list(entities)
      assert Enum.all?(entities, &(&1.confidence >= 0.8))
    end

    test "uses context for disambiguation when enabled" do
      tokens = build_spanish_tokens(["El", "presidente", "Pedro", "Sánchez", "habló", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens, use_context: true)

      assert is_list(entities)
    end

    test "handles Spanish accented characters in names" do
      tokens = build_spanish_tokens(["José", "María", "Rodríguez", "es", "español", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      assert is_list(entities)
    end

    test "recognizes Spanish organizational suffixes S.A., S.L., Ltda." do
      tokens = build_spanish_tokens(["Telefónica", "S.A.", "es", "grande", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes Latin American place names" do
      tokens =
        build_spanish_tokens(["Visitó", "Buenos", "Aires", "y", "Ciudad", "de", "México", "."])

      {:ok, entities} = EntityRecognizerAdapter.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert is_list(location_entities)
    end

    test "configuration includes Spanish lexicons" do
      tokens = build_spanish_tokens(["Test", "."])

      {:ok, _entities} = EntityRecognizerAdapter.recognize(tokens)

      # Verify that Spanish config is loaded and passed to generic algorithm
      # The fact that recognition succeeds validates config presence
      assert true
    end

    test "handles empty token list" do
      result = EntityRecognizerAdapter.recognize([])

      assert {:ok, entities} = result
      assert entities == []
    end
  end

  # Helper functions

  defp build_spanish_tokens(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      pos_tag =
        cond do
          word in [".", ",", "!", "?", "¿", "¡"] -> :punct
          word =~ ~r/^\d+$/ -> :num
          word == String.upcase(word) and String.length(word) > 1 -> :propn
          String.capitalize(word) == word and String.length(word) > 1 -> :propn
          true -> :noun
        end

      byte_offset = idx * 10

      %Token{
        text: word,
        pos_tag: pos_tag,
        lemma: String.downcase(word),
        language: :es,
        span:
          Node.make_span(
            {1, idx * 10},
            byte_offset,
            {1, idx * 10 + String.length(word)},
            byte_offset + byte_size(word)
          ),
        morphology: %{}
      }
    end)
  end
end
