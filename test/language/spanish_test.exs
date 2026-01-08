defmodule Nasty.Language.SpanishTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.Spanish

  describe "language_code/0" do
    test "returns :es" do
      assert Spanish.language_code() == :es
    end
  end

  describe "metadata/0" do
    test "returns Spanish language metadata" do
      meta = Spanish.metadata()

      assert meta.name == "Spanish"
      assert meta.native_name == "Español"
      assert meta.iso_639_1 == "es"
      assert meta.family == "Indo-European"
      assert meta.branch == "Romance"
    end

    test "lists supported features" do
      meta = Spanish.metadata()

      assert :tokenization in meta.features
      assert :pos_tagging in meta.features
      assert :lemmatization in meta.features
    end
  end

  describe "tokenize/1" do
    test "tokenizes Spanish text" do
      {:ok, tokens} = Spanish.tokenize("El gato duerme.")

      assert match?([_, _, _, _], tokens)
      assert Enum.map(tokens, & &1.text) == ["El", "gato", "duerme", "."]
    end

    test "handles empty string" do
      {:ok, tokens} = Spanish.tokenize("")
      assert tokens == []
    end
  end

  describe "tag_pos/1" do
    test "tags parts of speech" do
      {:ok, tokens} = Spanish.tokenize("El gato duerme.")
      {:ok, tagged} = Spanish.tag_pos(tokens)

      assert match?([_, _, _, _], tagged)
      assert Enum.any?(tagged, &(&1.pos_tag == :det))
      assert Enum.any?(tagged, &(&1.pos_tag == :noun))
      assert Enum.any?(tagged, &(&1.pos_tag == :verb))
    end
  end

  describe "parse/1" do
    test "parses simple sentence into document" do
      {:ok, tokens} = Spanish.tokenize("El gato duerme.")
      {:ok, tagged} = Spanish.tag_pos(tokens)
      {:ok, doc} = Spanish.parse(tagged)

      assert doc.language == :es
      assert match?([_], doc.paragraphs)
      assert doc.metadata.sentence_count >= 1
    end

    test "handles complex sentence with subordination" do
      {:ok, tokens} = Spanish.tokenize("Juan dijo que María vendría.")
      {:ok, tagged} = Spanish.tag_pos(tokens)
      {:ok, doc} = Spanish.parse(tagged)

      assert doc.language == :es
      assert match?([_], doc.paragraphs)
    end
  end

  describe "render/1" do
    test "renders document back to text" do
      text = "El gato duerme"
      {:ok, tokens} = Spanish.tokenize(text)
      {:ok, tagged} = Spanish.tag_pos(tokens)
      {:ok, doc} = Spanish.parse(tagged)
      {:ok, rendered} = Spanish.render(doc)

      assert is_binary(rendered)
      assert String.contains?(rendered, "gato")
      assert String.contains?(rendered, "duerme")
    end
  end
end
