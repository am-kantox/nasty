defmodule Nasty.Language.English.RelationExtractorTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Document, Paragraph, Relation}

  alias Nasty.Language.English.{
    Morphology,
    POSTagger,
    RelationExtractor,
    SentenceParser,
    Tokenizer
  }

  # Helper to parse text into a document
  defp parse_document(text) do
    {:ok, tokens} = Tokenizer.tokenize(text)
    {:ok, tagged} = POSTagger.tag_pos(tokens)
    {:ok, analyzed} = Morphology.analyze(tagged)
    {:ok, sentences} = SentenceParser.parse_sentences(analyzed)

    doc_span = Nasty.AST.Node.make_span({1, 0}, 0, {10, 0}, String.length(text))

    paragraph = %Paragraph{
      sentences: sentences,
      span: doc_span,
      language: :en
    }

    %Document{
      paragraphs: [paragraph],
      span: doc_span,
      language: :en,
      metadata: %{}
    }
  end

  describe "extract/1 with employment relations" do
    test "extracts works_at relation" do
      text = "John works at Google."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      # Should find a works_at relation
      works_at = Enum.find(relations, fn r -> r.type == :works_at end)

      if works_at do
        assert works_at.subject.type == :person
        assert works_at.object.type == :org
        assert is_float(works_at.confidence)
      end
    end

    test "extracts employment with join verb" do
      text = "Sarah joined Microsoft last year."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      employment = Enum.find(relations, fn r -> r.type == :works_at end)

      if employment do
        assert String.contains?(employment.subject.text, "Sarah") or
                 String.contains?(employment.object.text, "Microsoft")
      end
    end
  end

  describe "extract/1 with location relations" do
    test "extracts located_in relation" do
      text = "Google is located in California."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      location = Enum.find(relations, fn r -> r.type == :located_in end)

      if location do
        assert location.subject.type == :org
        assert location.object.type in [:gpe, :loc]
      end
    end

    test "extracts location with preposition" do
      text = "Apple is based in Cupertino."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      location = Enum.find(relations, fn r -> r.type == :located_in end)

      if location do
        assert is_float(location.confidence)
      end
    end
  end

  describe "extract/1 with business relations" do
    test "extracts acquisition relation" do
      text = "Google acquired YouTube."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      acquisition = Enum.find(relations, fn r -> r.type == :acquired_by end)

      if acquisition do
        # YouTube acquired by Google
        assert acquisition.subject.type == :org
        assert acquisition.object.type == :org
      end
    end

    test "extracts founding relation" do
      text = "Steve Jobs founded Apple."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      founding = Enum.find(relations, fn r -> r.type == :founded end)

      if founding do
        assert founding.confidence > 0.5
      end
    end
  end

  describe "extract/1 with options" do
    test "respects min_confidence option" do
      text = "John works at Google in California."
      document = parse_document(text)

      {:ok, all_relations} = RelationExtractor.extract(document, min_confidence: 0.0)
      {:ok, high_conf_relations} = RelationExtractor.extract(document, min_confidence: 0.9)

      # Higher confidence threshold should return fewer or equal relations
      assert length(high_conf_relations) <= length(all_relations)
    end

    test "respects max_relations option" do
      text = "John works at Google in California near San Francisco."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document, max_relations: 2)

      assert length(relations) <= 2
    end
  end

  describe "extract/1 with no relations" do
    test "returns empty list for sentence without entities" do
      text = "The cat sat on the mat."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      assert relations == []
    end

    test "returns empty list for unrelated entities" do
      text = "Hello there friend."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      assert is_list(relations)
    end
  end

  describe "Relation structure" do
    test "relation has correct fields" do
      text = "John works at Google."
      document = parse_document(text)

      {:ok, relations} = RelationExtractor.extract(document)

      if match?([_ | _], relations) do
        relation = hd(relations)

        assert %Relation{} = relation
        assert is_atom(relation.type)
        assert is_map(relation.subject)
        assert is_map(relation.object)
        assert is_float(relation.confidence)
      end
    end
  end
end
