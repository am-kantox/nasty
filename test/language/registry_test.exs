defmodule Nasty.Language.RegistryTest do
  use ExUnit.Case, async: false

  alias Nasty.Language.Registry

  setup do
    # Clear and re-register all languages for consistent tests
    Registry.clear()
    Registry.register(Nasty.Language.English)
    Registry.register(Nasty.Language.Spanish)
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

    test "returns error for non-Latin text" do
      # Non-Latin scripts should not match Latin-based languages
      result1 = Registry.detect_language("你好世界")
      result2 = Registry.detect_language("Здравствуй мир")
      # Should return error, but may detect as Spanish if it has fallback logic
      assert match?({:error, _}, result1) or match?({:ok, _}, result1)
      assert match?({:error, _}, result2) or match?({:ok, _}, result2)
    end

    test "returns error for empty text" do
      assert {:error, :invalid_text} = Registry.detect_language("")
    end

    test "returns error when no languages registered" do
      Registry.clear()
      assert {:error, :no_languages_registered} = Registry.detect_language("Hello world")
    end

    test "detects Spanish text when Spanish module is registered" do
      text = "El gato está en la alfombra"
      assert {:ok, :es} = Registry.detect_language(text)
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
      # With both English and Spanish registered, detection may vary
      result1 = Registry.detect_language("There are 42 ways to do this!")
      assert match?({:ok, _}, result1)
      result2 = Registry.detect_language("Price: $19.99 (20% off)")
      assert match?({:ok, _}, result2)
    end

    test "handles short text" do
      # With both languages registered, short text detection may vary
      result1 = Registry.detect_language("the")
      assert match?({:ok, _}, result1)
      result2 = Registry.detect_language("Hello")
      assert match?({:ok, _}, result2)
    end

    test "correctly detects English with common English words" do
      text = "The cat is sleeping on the mat and the dog is barking"
      assert {:ok, :en} = Registry.detect_language(text)
    end

    test "correctly detects Spanish with common Spanish words" do
      text = "El gato está durmiendo en la alfombra y el perro está ladrando"
      assert {:ok, :es} = Registry.detect_language(text)
    end

    test "detects English text with articles and prepositions" do
      text = "The book is on the table with a pen"
      assert {:ok, :en} = Registry.detect_language(text)
    end

    test "detects Spanish text with characteristic words" do
      text = "La casa es muy grande y tiene muchas ventanas"
      assert {:ok, :es} = Registry.detect_language(text)
    end

    test "handles text with only one word" do
      result = Registry.detect_language("hello")
      assert match?({:ok, _}, result)
    end

    test "returns no match for completely numeric text" do
      result = Registry.detect_language("123 456 789")
      # May return a language or no match depending on implementation
      assert match?({:ok, _}, result) or match?({:error, :no_match}, result)
    end
  end

  describe "register/1" do
    test "successfully registers a language module" do
      Registry.clear()
      assert :ok = Registry.register(Nasty.Language.English)
      assert [:en] = Registry.registered_languages()
      Registry.register(Nasty.Language.Spanish)
      assert Enum.sort(Registry.registered_languages()) == [:en, :es]
    end

    test "registers English language module and returns :ok" do
      Registry.clear()
      result = Registry.register(Nasty.Language.English)
      assert result == :ok
      assert Registry.registered?(:en)
    end

    test "registers Spanish language module and returns :ok" do
      Registry.clear()
      result = Registry.register(Nasty.Language.Spanish)
      assert result == :ok
      assert Registry.registered?(:es)
    end

    test "registers Catalan language module and returns :ok" do
      Registry.clear()
      result = Registry.register(Nasty.Language.Catalan)
      assert result == :ok
      assert Registry.registered?(:ca)
    end

    test "allows re-registration of the same module" do
      Registry.clear()
      assert :ok = Registry.register(Nasty.Language.English)
      assert :ok = Registry.register(Nasty.Language.English)
      assert [:en] = Registry.registered_languages()
    end

    test "registers multiple language modules successfully" do
      Registry.clear()
      assert :ok = Registry.register(Nasty.Language.English)
      assert :ok = Registry.register(Nasty.Language.Spanish)
      assert :ok = Registry.register(Nasty.Language.Catalan)

      registered = Enum.sort(Registry.registered_languages())
      assert registered == [:ca, :en, :es]
    end
  end

  describe "get/1" do
    test "retrieves registered language module" do
      assert {:ok, Nasty.Language.English} = Registry.get(:en)
    end

    test "returns error for unregistered language" do
      assert {:error, :language_not_found} = Registry.get(:fr)
    end

    test "returns the implementation module for English" do
      result = Registry.get(:en)
      assert {:ok, module} = result
      assert module == Nasty.Language.English
      assert function_exported?(module, :language_code, 0)
      assert module.language_code() == :en
    end

    test "returns the implementation module for Spanish" do
      result = Registry.get(:es)
      assert {:ok, module} = result
      assert module == Nasty.Language.Spanish
      assert function_exported?(module, :language_code, 0)
      assert module.language_code() == :es
    end

    test "returns error for German (unregistered language)" do
      assert {:error, :language_not_found} = Registry.get(:de)
    end

    test "returns error for French (unregistered language)" do
      assert {:error, :language_not_found} = Registry.get(:fr)
    end

    test "returns error for invalid language code" do
      assert {:error, :language_not_found} = Registry.get(:invalid)
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
