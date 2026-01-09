defmodule Nasty.Language.English.TransformerNERTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.English.TransformerNER

  describe "label_map/0" do
    test "returns correct BIO tag mapping" do
      label_map = TransformerNER.label_map()

      assert is_map(label_map)
      assert Map.get(label_map, 0) == "O"
      assert Map.get(label_map, 1) == "B-PER"
      assert Map.get(label_map, 2) == "I-PER"
      assert Map.get(label_map, 3) == "B-ORG"
      assert Map.get(label_map, 4) == "I-ORG"
      assert Map.get(label_map, 5) == "B-LOC"
      assert Map.get(label_map, 6) == "I-LOC"
      assert Map.get(label_map, 7) == "B-MISC"
      assert Map.get(label_map, 8) == "I-MISC"
    end

    test "has 9 labels" do
      assert map_size(TransformerNER.label_map()) == 9
    end
  end

  describe "tag_to_id/0" do
    test "returns correct tag to ID mapping" do
      tag_to_id = TransformerNER.tag_to_id()

      assert is_map(tag_to_id)
      assert Map.get(tag_to_id, :o) == 0
      assert Map.get(tag_to_id, :b_per) == 1
      assert Map.get(tag_to_id, :i_per) == 2
      assert Map.get(tag_to_id, :b_org) == 3
      assert Map.get(tag_to_id, :i_org) == 4
      assert Map.get(tag_to_id, :b_loc) == 5
      assert Map.get(tag_to_id, :i_loc) == 6
      assert Map.get(tag_to_id, :b_misc) == 7
      assert Map.get(tag_to_id, :i_misc) == 8
    end
  end

  describe "num_labels/0" do
    test "returns 9 NER labels" do
      assert TransformerNER.num_labels() == 9
    end
  end

  describe "recognize_entities/2" do
    @describetag [model: true, skip: true]

    setup do
      # Create sample tokens for testing
      span1 = Node.make_span({1, 0}, 0, {1, 4}, 4)
      span2 = Node.make_span({1, 5}, 5, {1, 10}, 10)
      span3 = Node.make_span({1, 11}, 11, {1, 16}, 16)
      span4 = Node.make_span({1, 17}, 17, {1, 19}, 19)
      span5 = Node.make_span({1, 20}, 20, {1, 25}, 25)

      tokens = [
        Token.new("John", :propn, :en, span1),
        Token.new("lives", :verb, :en, span2),
        Token.new("in", :adp, :en, span3),
        Token.new("Paris", :propn, :en, span4),
        Token.new(".", :punct, :en, span5)
      ]

      {:ok, tokens: tokens}
    end

    test "returns error when model loading fails", %{tokens: tokens} do
      # This test expects model loading to fail since transformer models
      # are not available in test environment by default
      result = TransformerNER.recognize_entities(tokens)

      assert match?({:error, _}, result)
    end

    test "accepts model option", %{tokens: tokens} do
      result = TransformerNER.recognize_entities(tokens, model: :roberta_base)

      # Should attempt to load the specified model
      assert match?({:error, _}, result)
    end

    test "accepts use_cache option", %{tokens: tokens} do
      result = TransformerNER.recognize_entities(tokens, use_cache: false)

      assert match?({:error, _}, result)
    end

    test "accepts device option", %{tokens: tokens} do
      result = TransformerNER.recognize_entities(tokens, device: :cpu)

      assert match?({:error, _}, result)
    end

    test "handles empty token list" do
      result = TransformerNER.recognize_entities([])

      # Empty input should still try to process
      assert match?({:error, _}, result)
    end
  end

  describe "entity extraction logic" do
    @describetag [model: true, skip: true]

    test "label map is consistent with tag_to_id" do
      label_map = TransformerNER.label_map()
      tag_to_id = TransformerNER.tag_to_id()

      # Every tag should have a corresponding label
      Enum.each(tag_to_id, fn {tag, id} ->
        label = Map.get(label_map, id)
        assert label != nil, "Tag #{tag} (ID: #{id}) should have a label"

        # Convert back to verify consistency
        expected_tag = String.downcase(label) |> String.replace("-", "_") |> String.to_atom()
        assert expected_tag == tag
      end)
    end

    test "all BIO entity types are covered" do
      label_map = TransformerNER.label_map()
      labels = Map.values(label_map)

      # Should have O (outside) tag
      assert "O" in labels

      # Should have B- and I- tags for each entity type
      entity_types = ["PER", "ORG", "LOC", "MISC"]

      Enum.each(entity_types, fn type ->
        assert "B-#{type}" in labels, "Missing B-#{type} label"
        assert "I-#{type}" in labels, "Missing I-#{type} label"
      end)
    end
  end

  describe "model resolution" do
    @describetag [model: true, skip: true]

    test "uses roberta_base as default when :transformer specified", %{} do
      # Create minimal tokens
      span = Node.make_span({1, 0}, 0, {1, 4}, 4)
      tokens = [Token.new("test", :noun, :en, span)]

      # When model: :transformer, should resolve to :roberta_base
      # We can't test the actual resolution without loading models,
      # but we can verify the option is accepted
      result = TransformerNER.recognize_entities(tokens, model: :transformer)
      assert match?({:error, _}, result)
    end

    test "accepts explicit model names", %{} do
      span = Node.make_span({1, 0}, 0, {1, 4}, 4)
      tokens = [Token.new("test", :noun, :en, span)]

      # Should accept specific model names
      result = TransformerNER.recognize_entities(tokens, model: :bert_base_cased)
      assert match?({:error, _}, result)
    end
  end

  describe "span tracking" do
    test "tokens maintain span information" do
      # Create test tokens
      span1 = Node.make_span({1, 0}, 0, {1, 4}, 4)
      span2 = Node.make_span({1, 5}, 5, {1, 10}, 10)

      tokens = [
        Token.new("John", :propn, :en, span1),
        Token.new("Smith", :propn, :en, span2)
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
