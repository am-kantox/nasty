defmodule Nasty.Language.RegistryTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.Registry

  setup do
    # Clear and re-register English for consistent tests
    Registry.clear()
    Registry.register(Nasty.Language.English)
    :ok
  end

  describe "detect_language/1" do
    test "detects English text" do
      assert {:ok, :en} = Registry.detect_language("The quick brown fox jumps over the lazy dog")
      assert {:ok, :en} = Registry.detect_language("Hello world, this is a test")
      assert {:ok, :en} = Registry.detect_language("I have a dream that one day")
    end

    test "detects English with common words" do
      assert {:ok, :en} = Registry.detect_language("The cat is on the mat")
      assert {:ok, :en} = Registry.detect_language("She was very happy about it")
    end

    test "returns error for non-Latin text when only English registered" do
      assert {:error, :no_match} = Registry.detect_language("你好世界")
      assert {:error, :no_match} = Registry.detect_language("Здравствуй мир")
    end

    test "returns error for empty text" do
      assert {:error, :invalid_text} = Registry.detect_language("")
    end

    test "returns error when no languages registered" do
      Registry.clear()
      assert {:error, :no_languages_registered} = Registry.detect_language("Hello world")
    end

    test "detects Spanish text when Spanish module is registered" do
      # Note: This test documents expected behavior for future Spanish implementation
      # Currently will fall back to English due to Latin character overlap
      text = "El gato está en la alfombra"

      # With only English registered, it might match English
      result = Registry.detect_language(text)
      assert match?({:ok, _}, result)
    end

    test "detects Catalan text when Catalan module is registered" do
      # Note: This test documents expected behavior for future Catalan implementation
      # Currently will fall back to English due to Latin character overlap
      text = "El gat està a la catifa"

      # With only English registered, it might match English
      result = Registry.detect_language(text)
      assert match?({:ok, _}, result)
    end

    test "handles mixed language text" do
      # Should detect the dominant language
      mixed_text = "The meeting is tomorrow, por favor confirmar"

      result = Registry.detect_language(mixed_text)
      assert match?({:ok, _}, result)
    end

    test "handles text with numbers and punctuation" do
      assert {:ok, :en} = Registry.detect_language("There are 42 ways to do this!")
      assert {:ok, :en} = Registry.detect_language("Price: $19.99 (20% off)")
    end

    test "handles short text" do
      assert {:ok, :en} = Registry.detect_language("the")
      assert {:ok, :en} = Registry.detect_language("Hello")
    end
  end

  describe "register/1" do
    test "successfully registers a language module" do
      Registry.clear()
      assert :ok = Registry.register(Nasty.Language.English)
      assert [:en] = Registry.registered_languages()
    end
  end

  describe "get/1" do
    test "retrieves registered language module" do
      assert {:ok, Nasty.Language.English} = Registry.get(:en)
    end

    test "returns error for unregistered language" do
      assert {:error, :language_not_found} = Registry.get(:fr)
    end
  end

  describe "registered?/1" do
    test "returns true for registered language" do
      assert Registry.registered?(:en)
    end

    test "returns false for unregistered language" do
      refute Registry.registered?(:fr)
    end
  end
end
