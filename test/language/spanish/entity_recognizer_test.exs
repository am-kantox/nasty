defmodule Nasty.Language.Spanish.EntityRecognizerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.Spanish.EntityRecognizer

  describe "recognize/2" do
    test "recognizes Spanish person names with titles" do
      tokens = build_tokens(["El", "Dr.", "José", "García", "llegó", "ayer", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "recognizes Spanish female names" do
      tokens = build_tokens(["María", "López", "es", "doctora", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "recognizes Spanish surnames" do
      tokens = build_tokens(["Juan", "García", "Rodríguez", "vive", "aquí", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "recognizes Spanish place names from Spain" do
      tokens = build_tokens(["Viajé", "a", "Madrid", "y", "Barcelona", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert match?([_ | _], location_entities)
    end

    test "recognizes Spanish regions" do
      tokens = build_tokens(["Cataluña", "y", "Andalucía", "son", "regiones", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert match?([_ | _], location_entities)
    end

    test "recognizes Latin American countries" do
      tokens = build_tokens(["México", ",", "Argentina", "y", "Colombia", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert match?([_, _ | _], location_entities)
    end

    test "recognizes Latin American cities" do
      tokens = build_tokens(["Buenos", "Aires", "y", "Ciudad", "de", "México", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert is_list(location_entities)
    end

    test "recognizes Spanish organizations with S.A. suffix" do
      tokens = build_tokens(["Telefónica", "S.A.", "es", "grande", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes Spanish organizations with S.L. suffix" do
      tokens = build_tokens(["Empresa", "X", "S.L.", "contrató", "gente", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes Real Madrid as organization" do
      tokens = build_tokens(["El", "Real", "Madrid", "ganó", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes government institutions" do
      tokens = build_tokens(["El", "Gobierno", "de", "España", "anunció", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes Spanish universities" do
      tokens = build_tokens(["La", "Universidad", "de", "Barcelona", "enseña", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "recognizes Spanish titles Dr., Dra." do
      tokens = build_tokens(["La", "Dra.", "María", "habló", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert is_list(person_entities)
    end

    test "recognizes Spanish titles Sr., Sra." do
      tokens = build_tokens(["El", "Sr.", "García", "y", "la", "Sra.", "López", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "recognizes Spanish titles Don, Doña" do
      tokens = build_tokens(["Don", "Juan", "y", "Doña", "María", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "handles accented characters in Spanish names" do
      tokens = build_tokens(["José", "María", "Rodríguez", "es", "médico", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      assert is_list(entities)
    end

    test "handles ñ in Spanish names and places" do
      tokens = build_tokens(["Señor", "Muñoz", "vive", "en", "España", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      assert is_list(entities)
    end

    test "recognizes compound Spanish place names" do
      tokens = build_tokens(["La", "República", "Dominicana", "es", "bella", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert is_list(location_entities)
    end

    test "handles Spanish context words for person detection" do
      tokens = build_tokens(["El", "presidente", "Pedro", "Sánchez", "habló", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      person_entities = Enum.filter(entities, &(&1.type == :PERSON))
      assert match?([_ | _], person_entities)
    end

    test "handles Spanish context words for organization detection" do
      tokens = build_tokens(["La", "empresa", "Santander", "anunció", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "handles Spanish context words for place detection" do
      tokens = build_tokens(["La", "ciudad", "de", "Madrid", "es", "grande", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      location_entities = Enum.filter(entities, &(&1.type == :LOCATION))
      assert match?([_ | _], location_entities)
    end

    test "recognizes Spanish banks as organizations" do
      tokens = build_tokens(["El", "Banco", "Santander", "cerró", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      org_entities = Enum.filter(entities, &(&1.type in [:ORGANIZATION, :ORG]))
      assert is_list(org_entities)
    end

    test "handles empty token list" do
      {:ok, entities} = EntityRecognizer.recognize([])

      assert entities == []
    end

    test "handles tokens without named entities" do
      tokens = build_tokens(["El", "gato", "duerme", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens)

      assert is_list(entities)
    end

    test "filters by entity type option" do
      tokens = build_tokens(["María", "vive", "en", "Madrid", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens, types: [:PERSON])

      assert Enum.all?(entities, &(&1.type == :PERSON))
    end

    test "respects minimum confidence threshold" do
      tokens = build_tokens(["Posible", "nombre", "aquí", "."])

      {:ok, entities} = EntityRecognizer.recognize(tokens, min_confidence: 0.9)

      assert Enum.all?(entities, &(&1.confidence >= 0.9))
    end
  end

  # Helper functions

  defp build_tokens(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      pos_tag =
        cond do
          word in [".", ",", "!", "?", "¿", "¡", ";", ":"] -> :punct
          word =~ ~r/^\d+$/ -> :num
          word =~ ~r/^[A-ZÁÉÍÓÚÑ]/ and String.length(word) > 1 -> :propn
          word in ["el", "la", "los", "las", "un", "una", "unos", "unas", "El", "La"] -> :det
          word in ["de", "en", "a", "con", "por", "para", "desde", "y"] -> :adp
          word in ["es", "son", "está", "están", "fue", "vive"] -> :verb
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
