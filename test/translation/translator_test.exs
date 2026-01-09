defmodule Nasty.Translation.TranslatorTest do
  use ExUnit.Case, async: true

  alias Nasty.Translation.Translator

  describe "translate/4 - Simple sentences" do
    test "translates simple English noun to Spanish" do
      # Simple test with single word
      assert {:ok, translated} = Translator.translate("cat", :en, :es)
      assert String.downcase(translated) =~ "gato"
    end

    test "translates simple Spanish noun to English" do
      assert {:ok, translated} = Translator.translate("gato", :es, :en)
      assert String.downcase(translated) =~ "cat"
    end

    @tag :skip
    test "translates simple English noun to Catalan" do
      assert {:ok, translated} = Translator.translate("cat", :en, :ca)
      assert String.downcase(translated) =~ "gat"
    end

    test "handles empty string" do
      assert {:ok, ""} = Translator.translate("", :en, :es)
    end

    test "rejects same language translation" do
      assert {:error, :same_language} = Translator.translate("cat", :en, :en)
    end

    test "rejects unsupported languages" do
      assert {:error, {:unsupported_language, :fr}} = Translator.translate("chat", :fr, :en)
      assert {:error, {:unsupported_language, :de}} = Translator.translate("cat", :en, :de)
    end
  end

  describe "translate_document/3" do
    test "rejects same language translation" do
      alias Nasty.AST.{Document, Node}

      span = Node.make_span({1, 0}, 0, {1, 3}, 3)
      doc = %Document{language: :en, paragraphs: [], span: span}

      assert {:error, :same_language} = Translator.translate_document(doc, :en)
    end
  end

  describe "supported_pairs/0" do
    test "returns all language pairs" do
      pairs = Translator.supported_pairs()

      assert {:en, :es} in pairs
      assert {:es, :en} in pairs
      assert {:en, :ca} in pairs
      assert {:ca, :en} in pairs
      assert {:es, :ca} in pairs
      assert {:ca, :es} in pairs

      # Should not include same-language pairs
      refute {:en, :en} in pairs
      refute {:es, :es} in pairs
      refute {:ca, :ca} in pairs
    end

    test "returns exactly 6 pairs" do
      pairs = Translator.supported_pairs()
      assert [_, _, _, _, _, _] = pairs
    end
  end

  describe "supports?/2" do
    test "returns true for supported pairs" do
      assert Translator.supports?(:en, :es)
      assert Translator.supports?(:es, :en)
      assert Translator.supports?(:en, :ca)
      assert Translator.supports?(:ca, :en)
      assert Translator.supports?(:es, :ca)
      assert Translator.supports?(:ca, :es)
    end

    test "returns false for same language" do
      refute Translator.supports?(:en, :en)
      refute Translator.supports?(:es, :es)
      refute Translator.supports?(:ca, :ca)
    end

    test "returns false for unsupported languages" do
      refute Translator.supports?(:en, :fr)
      refute Translator.supports?(:fr, :en)
      refute Translator.supports?(:de, :es)
    end
  end
end
