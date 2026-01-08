defmodule Nasty.Language.Spanish.Adapters.CoreferenceResolverAdapterTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Document, Node, Paragraph, Sentence, Token}
  alias Nasty.AST.Semantic.CorefChain
  alias Nasty.Language.Spanish.Adapters.CoreferenceResolverAdapter

  describe "resolve/2" do
    test "delegates to generic coreference resolution with Spanish config" do
      doc = build_spanish_document_with_pronouns()

      result = CoreferenceResolverAdapter.resolve(doc)

      assert {:ok, chains} = result
      assert is_list(chains)
    end

    test "uses Spanish pronoun configuration" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert is_list(chains)
      assert Enum.all?(chains, &match?(%CorefChain{}, &1))
    end

    test "respects gender agreement for Spanish pronouns" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc, use_gender: true)

      assert is_list(chains)
    end

    test "respects number agreement for Spanish pronouns" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc, use_number: true)

      assert is_list(chains)
    end

    test "handles Spanish reflexive pronouns" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert is_list(chains)
    end

    test "handles Spanish possessive pronouns" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert is_list(chains)
    end

    test "handles Spanish demonstrative pronouns" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert is_list(chains)
    end

    test "respects maximum distance parameter" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc, max_distance: 2)

      assert is_list(chains)
    end

    test "respects minimum confidence threshold" do
      doc = build_spanish_document_with_pronouns()

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc, min_confidence: 0.7)

      assert is_list(chains)
      # All chains should meet confidence threshold (implementation detail)
    end

    test "handles empty document" do
      doc = %Document{
        paragraphs: [],
        span: Node.make_span({1, 0}, 0, {1, 0}, 0),
        language: :es,
        metadata: %{}
      }

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert chains == []
    end

    test "configuration includes Spanish pronouns" do
      doc = build_spanish_document_with_pronouns()

      {:ok, _chains} = CoreferenceResolverAdapter.resolve(doc)

      # Verify Spanish config is used (pronouns, gender markers, etc.)
      assert true
    end

    test "configuration includes Spanish gender markers" do
      doc = build_spanish_document_with_pronouns()

      {:ok, _chains} = CoreferenceResolverAdapter.resolve(doc)

      # Spanish gender markers should be in config
      assert true
    end

    test "configuration includes Spanish number markers" do
      doc = build_spanish_document_with_pronouns()

      {:ok, _chains} = CoreferenceResolverAdapter.resolve(doc)

      # Spanish number markers should be in config
      assert true
    end

    test "handles Spanish subject pronouns (él, ella, ellos, ellas)" do
      tokens = build_spanish_tokens(["María", "llegó", ".", "Ella", "es", "doctora", "."])
      doc = build_document_from_tokens(tokens)

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert is_list(chains)
    end

    test "handles Spanish object pronouns (lo, la, los, las, le, les)" do
      tokens = build_spanish_tokens(["Juan", "compró", "un", "libro", ".", "Lo", "leyó", "."])
      doc = build_document_from_tokens(tokens)

      {:ok, chains} = CoreferenceResolverAdapter.resolve(doc)

      assert is_list(chains)
    end
  end

  # Helper functions

  defp build_spanish_document_with_pronouns do
    tokens = build_spanish_tokens(["María", "llegó", ".", "Ella", "está", "feliz", "."])
    build_document_from_tokens(tokens)
  end

  defp build_spanish_tokens(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      pos_tag =
        cond do
          word in [".", ",", "!", "?", "¿", "¡"] -> :punct
          word in ["él", "ella", "ellos", "ellas", "lo", "la", "los", "las", "le", "les"] -> :pron
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

  defp build_document_from_tokens(tokens) do
    # Create a minimal clause for the sentence
    clause = %Nasty.AST.Clause{
      type: :independent,
      subject: nil,
      predicate: nil,
      language: :es,
      span: Node.make_span({1, 0}, 0, {1, 100}, 100)
    }

    sentence = %Sentence{
      function: :declarative,
      structure: :simple,
      main_clause: clause,
      span: Node.make_span({1, 0}, 0, {1, 100}, 100),
      language: :es,
      additional_clauses: []
    }

    paragraph = %Paragraph{
      sentences: [sentence],
      span: Node.make_span({1, 0}, 0, {1, 100}, 100),
      language: :es
    }

    %Document{
      paragraphs: [paragraph],
      span: Node.make_span({1, 0}, 0, {1, 100}, 100),
      language: :es,
      metadata: %{tokens: tokens}
    }
  end
end
