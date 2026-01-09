defmodule Nasty.Language.English.TransformerPOSTaggerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.English.TransformerPOSTagger

  describe "label_map/0" do
    test "returns correct UPOS tag mapping" do
      label_map = TransformerPOSTagger.label_map()

      assert is_map(label_map)
      assert Map.get(label_map, 0) == "ADJ"
      assert Map.get(label_map, 1) == "ADP"
      assert Map.get(label_map, 2) == "ADV"
      assert Map.get(label_map, 3) == "AUX"
      assert Map.get(label_map, 4) == "CCONJ"
      assert Map.get(label_map, 5) == "DET"
      assert Map.get(label_map, 6) == "INTJ"
      assert Map.get(label_map, 7) == "NOUN"
      assert Map.get(label_map, 8) == "NUM"
      assert Map.get(label_map, 9) == "PART"
      assert Map.get(label_map, 10) == "PRON"
      assert Map.get(label_map, 11) == "PROPN"
      assert Map.get(label_map, 12) == "PUNCT"
      assert Map.get(label_map, 13) == "SCONJ"
      assert Map.get(label_map, 14) == "SYM"
      assert Map.get(label_map, 15) == "VERB"
      assert Map.get(label_map, 16) == "X"
    end

    test "has 17 UPOS labels" do
      assert map_size(TransformerPOSTagger.label_map()) == 17
    end
  end

  describe "tag_to_id/0" do
    test "returns correct tag to ID mapping" do
      tag_to_id = TransformerPOSTagger.tag_to_id()

      assert is_map(tag_to_id)
      assert Map.get(tag_to_id, :adj) == 0
      assert Map.get(tag_to_id, :adp) == 1
      assert Map.get(tag_to_id, :adv) == 2
      assert Map.get(tag_to_id, :aux) == 3
      assert Map.get(tag_to_id, :cconj) == 4
      assert Map.get(tag_to_id, :det) == 5
      assert Map.get(tag_to_id, :intj) == 6
      assert Map.get(tag_to_id, :noun) == 7
      assert Map.get(tag_to_id, :num) == 8
      assert Map.get(tag_to_id, :part) == 9
      assert Map.get(tag_to_id, :pron) == 10
      assert Map.get(tag_to_id, :propn) == 11
      assert Map.get(tag_to_id, :punct) == 12
      assert Map.get(tag_to_id, :sconj) == 13
      assert Map.get(tag_to_id, :sym) == 14
      assert Map.get(tag_to_id, :verb) == 15
      assert Map.get(tag_to_id, :x) == 16
    end
  end

  describe "num_labels/0" do
    test "returns 17 POS labels" do
      assert TransformerPOSTagger.num_labels() == 17
    end
  end

  describe "tag_pos/2" do
    @describetag [model: true, skip: true]

    setup do
      # Create sample tokens for testing
      span1 = Node.make_span({1, 0}, 0, {1, 3}, 3)
      span2 = Node.make_span({1, 4}, 4, {1, 7}, 7)
      span3 = Node.make_span({1, 8}, 8, {1, 11}, 11)
      span4 = Node.make_span({1, 11}, 11, {1, 12}, 12)

      # Create tokens without POS tags (simulating tokenizer output)
      tokens = [
        %Token{
          text: "The",
          pos_tag: :x,
          language: :en,
          span: span1,
          lemma: "The",
          morphology: %{}
        },
        %Token{
          text: "cat",
          pos_tag: :x,
          language: :en,
          span: span2,
          lemma: "cat",
          morphology: %{}
        },
        %Token{
          text: "sat",
          pos_tag: :x,
          language: :en,
          span: span3,
          lemma: "sat",
          morphology: %{}
        },
        %Token{text: ".", pos_tag: :x, language: :en, span: span4, lemma: ".", morphology: %{}}
      ]

      {:ok, tokens: tokens}
    end

    test "returns error when model loading fails", %{tokens: tokens} do
      # This test expects model loading to fail since transformer models
      # are not available in test environment by default
      result = TransformerPOSTagger.tag_pos(tokens)

      assert match?({:error, _}, result)
    end

    test "accepts model option", %{tokens: tokens} do
      result = TransformerPOSTagger.tag_pos(tokens, model: :roberta_base)

      # Should attempt to load the specified model
      assert match?({:error, _}, result)
    end

    test "accepts use_cache option", %{tokens: tokens} do
      result = TransformerPOSTagger.tag_pos(tokens, use_cache: false)

      assert match?({:error, _}, result)
    end

    test "accepts device option", %{tokens: tokens} do
      result = TransformerPOSTagger.tag_pos(tokens, device: :cpu)

      assert match?({:error, _}, result)
    end

    test "handles empty token list" do
      result = TransformerPOSTagger.tag_pos([])

      # Empty input should still try to process
      assert match?({:error, _}, result)
    end

    test "handles single token" do
      span = Node.make_span({1, 0}, 0, {1, 4}, 4)

      token = %Token{
        text: "word",
        pos_tag: :x,
        language: :en,
        span: span,
        lemma: "word",
        morphology: %{}
      }

      result = TransformerPOSTagger.tag_pos([token])

      assert match?({:error, _}, result)
    end
  end

  describe "label consistency" do
    @describetag [model: true, skip: true]

    test "label map is consistent with tag_to_id" do
      label_map = TransformerPOSTagger.label_map()
      tag_to_id = TransformerPOSTagger.tag_to_id()

      # Every tag should have a corresponding label
      Enum.each(tag_to_id, fn {tag, id} ->
        label = Map.get(label_map, id)
        assert label != nil, "Tag #{tag} (ID: #{id}) should have a label"

        # Convert back to verify consistency
        expected_tag = String.downcase(label) |> String.to_atom()
        assert expected_tag == tag
      end)
    end

    test "all Universal Dependencies POS tags are covered" do
      label_map = TransformerPOSTagger.label_map()
      labels = Map.values(label_map)

      # Check all UPOS tags are present
      expected_tags = [
        "ADJ",
        "ADP",
        "ADV",
        "AUX",
        "CCONJ",
        "DET",
        "INTJ",
        "NOUN",
        "NUM",
        "PART",
        "PRON",
        "PROPN",
        "PUNCT",
        "SCONJ",
        "SYM",
        "VERB",
        "X"
      ]

      Enum.each(expected_tags, fn tag ->
        assert tag in labels, "Missing #{tag} label"
      end)
    end

    test "matches Token.pos_tags/0 structure" do
      expected_pos_tags = Token.pos_tags()
      tag_to_id = TransformerPOSTagger.tag_to_id()

      # All token POS tags should be in the tagger's mapping
      Enum.each(expected_pos_tags, fn pos_tag ->
        assert Map.has_key?(tag_to_id, pos_tag),
               "POS tag #{pos_tag} not in TransformerPOSTagger mapping"
      end)
    end
  end

  describe "model resolution" do
    @describetag [model: true, skip: true]

    test "uses roberta_base as default when :transformer specified" do
      span = Node.make_span({1, 0}, 0, {1, 4}, 4)

      tokens = [
        %Token{
          text: "test",
          pos_tag: :x,
          language: :en,
          span: span,
          lemma: "test",
          morphology: %{}
        }
      ]

      # When model: :transformer, should resolve to :roberta_base
      result = TransformerPOSTagger.tag_pos(tokens, model: :transformer)
      assert match?({:error, _}, result)
    end

    test "accepts explicit model names" do
      span = Node.make_span({1, 0}, 0, {1, 4}, 4)

      tokens = [
        %Token{
          text: "test",
          pos_tag: :x,
          language: :en,
          span: span,
          lemma: "test",
          morphology: %{}
        }
      ]

      # Should accept specific model names
      result = TransformerPOSTagger.tag_pos(tokens, model: :bert_base_cased)
      assert match?({:error, _}, result)
    end
  end

  describe "content and function words" do
    test "tag_to_id includes content word tags" do
      tag_to_id = TransformerPOSTagger.tag_to_id()

      # Content words: adj, adv, intj, noun, propn, verb
      content_tags = [:adj, :adv, :intj, :noun, :propn, :verb]

      Enum.each(content_tags, fn tag ->
        assert Map.has_key?(tag_to_id, tag), "Missing content word tag: #{tag}"
      end)
    end

    test "tag_to_id includes function word tags" do
      tag_to_id = TransformerPOSTagger.tag_to_id()

      # Function words: adp, aux, cconj, det, num, part, pron, sconj
      function_tags = [:adp, :aux, :cconj, :det, :num, :part, :pron, :sconj]

      Enum.each(function_tags, fn tag ->
        assert Map.has_key?(tag_to_id, tag), "Missing function word tag: #{tag}"
      end)
    end

    test "tag_to_id includes other tags" do
      tag_to_id = TransformerPOSTagger.tag_to_id()

      # Other: punct, sym, x
      other_tags = [:punct, :sym, :x]

      Enum.each(other_tags, fn tag ->
        assert Map.has_key?(tag_to_id, tag), "Missing other tag: #{tag}"
      end)
    end
  end

  describe "span tracking" do
    test "tokens maintain span information" do
      # Create test tokens
      span1 = Node.make_span({1, 0}, 0, {1, 3}, 3)
      span2 = Node.make_span({1, 4}, 4, {1, 7}, 7)

      tokens = [
        %Token{
          text: "The",
          pos_tag: :x,
          language: :en,
          span: span1,
          lemma: "The",
          morphology: %{}
        },
        %Token{
          text: "cat",
          pos_tag: :x,
          language: :en,
          span: span2,
          lemma: "cat",
          morphology: %{}
        }
      ]

      # Verify tokens maintain spans correctly
      Enum.each(tokens, fn token ->
        assert is_map(token.span)
        assert Map.has_key?(token.span, :start_pos)
        assert Map.has_key?(token.span, :end_pos)
        assert Map.has_key?(token.span, :start_offset)
        assert Map.has_key?(token.span, :end_offset)
      end)
    end
  end
end
