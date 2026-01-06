defmodule Nasty.Language.English.EntityRecognizerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.Entity
  alias Nasty.Language.English.{EntityRecognizer, POSTagger, Tokenizer}

  describe "person entities" do
    test "recognizes single person name" do
      {:ok, tokens} = Tokenizer.tokenize("John works here.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      assert match?([_], entities)
      [entity] = entities

      assert entity.type == :person
      assert entity.text == "John"
    end

    test "recognizes full person name" do
      {:ok, tokens} = Tokenizer.tokenize("Mary Smith lives in Boston.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      # Should recognize "Mary Smith" and "Boston"
      assert match?([_ | _], entities)

      person = Enum.find(entities, fn e -> e.type == :person end)
      assert person != nil
      assert person.text == "Mary Smith"
    end

    test "recognizes person with title" do
      {:ok, tokens} = Tokenizer.tokenize("Dr Johnson visited.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      assert length(entities) == 1
      [entity] = entities

      assert entity.type == :person
      assert String.contains?(entity.text, "Johnson")
    end
  end

  describe "place entities" do
    test "recognizes known city" do
      {:ok, tokens} = Tokenizer.tokenize("I visited London.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      # Should find London as a place
      place = Enum.find(entities, fn e -> e.type == :gpe && e.text == "London" end)
      assert place != nil
    end

    test "recognizes multi-word place name" do
      {:ok, tokens} = Tokenizer.tokenize("We went to New York City.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      # Should recognize a place with "City" suffix or multi-word capitalized phrase
      place = Enum.find(entities, fn e -> e.type == :gpe end)
      assert place != nil
      assert String.contains?(place.text, "York")
    end

    test "recognizes place with suffix" do
      {:ok, tokens} = Tokenizer.tokenize("Welcome to Springfield City.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      place = Enum.find(entities, fn e -> e.type == :gpe end)
      assert place != nil
      assert place.text == "Springfield City"
    end
  end

  describe "organization entities" do
    test "recognizes known organization" do
      {:ok, tokens} = Tokenizer.tokenize("Google announced new features.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      assert match?([_ | _], entities)
      org = Enum.find(entities, fn e -> e.type == :org end)
      assert org != nil
      assert org.text == "Google"
    end

    test "recognizes organization with suffix" do
      {:ok, tokens} = Tokenizer.tokenize("Acme Corporation released a product.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      org = Enum.find(entities, fn e -> e.type == :org end)
      assert org != nil
      assert org.text == "Acme Corporation"
    end

    test "recognizes university" do
      {:ok, tokens} = Tokenizer.tokenize("She studied at Harvard University.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      org = Enum.find(entities, fn e -> e.type == :org end)
      assert org != nil
      assert String.contains?(org.text, "University")
    end
  end

  describe "multiple entities" do
    test "recognizes multiple entities in sentence" do
      {:ok, tokens} = Tokenizer.tokenize("John moved from London to Paris.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      # Should find: John (person), London (place), Paris (place)
      assert length(entities) == 3

      persons = Enum.filter(entities, fn e -> e.type == :person end)
      places = Enum.filter(entities, fn e -> e.type == :gpe end)

      assert length(persons) == 1
      assert length(places) == 2
    end

    test "recognizes entities in complex sentence" do
      {:ok, tokens} = Tokenizer.tokenize("Microsoft hired Sarah to work in Seattle.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      # Should find: Microsoft (org), Sarah (person), Seattle (place)
      assert length(entities) >= 2

      assert Enum.any?(entities, fn e -> e.type == :org end)
      assert Enum.any?(entities, fn e -> e.type == :person end)
    end
  end

  describe "edge cases" do
    test "handles sentence with no entities" do
      {:ok, tokens} = Tokenizer.tokenize("The cat sat on the mat.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      entities = EntityRecognizer.recognize(tagged)

      assert entities == []
    end

    test "returns empty list for empty input" do
      entities = EntityRecognizer.recognize([])
      assert entities == []
    end
  end

  describe "entity structure" do
    test "entity has correct structure" do
      {:ok, tokens} = Tokenizer.tokenize("John works.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [entity] = EntityRecognizer.recognize(tagged)

      assert %Entity{} = entity
      assert entity.type in Entity.entity_types()
      assert is_binary(entity.text)
      assert is_list(entity.tokens)
      assert match?([_ | _], entity.tokens)
      assert is_map(entity.span)
      assert is_float(entity.confidence) or is_nil(entity.confidence)
    end
  end
end
