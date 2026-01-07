defmodule Nasty.Language.English.AdaptersTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Document, Paragraph, Sentence, Token}
  alias Nasty.AST.Semantic.Entity

  alias Nasty.Language.English.Adapters.{
    CoreferenceResolverAdapter,
    EntityRecognizerAdapter,
    SummarizerAdapter
  }

  describe "SummarizerAdapter" do
    test "summarize/2 returns sentences from document" do
      # Create a realistic document with proper sentence structures
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)
      token = %Token{text: "sat", pos_tag: :verb, language: :en, span: span}

      clause = %Nasty.AST.Clause{
        type: :independent,
        predicate: %Nasty.AST.VerbPhrase{
          head: token,
          language: :en,
          span: span
        },
        language: :en,
        span: span
      }

      sentences = [
        %Sentence{
          function: :declarative,
          structure: :simple,
          main_clause: clause,
          language: :en,
          span: span
        },
        %Sentence{
          function: :declarative,
          structure: :simple,
          main_clause: clause,
          language: :en,
          span: span
        },
        %Sentence{
          function: :declarative,
          structure: :simple,
          main_clause: clause,
          language: :en,
          span: span
        }
      ]

      doc = %Document{
        language: :en,
        span: span,
        paragraphs: [
          %Paragraph{
            sentences: sentences,
            language: :en,
            span: span
          }
        ]
      }

      assert {:ok, result_sentences} = SummarizerAdapter.summarize(doc, ratio: 0.5)
      assert is_list(result_sentences)
      assert Enum.all?(result_sentences, &match?(%Sentence{}, &1))
    end

    test "methods/0 returns available summarization methods" do
      methods = SummarizerAdapter.methods()
      assert is_list(methods)
      assert :extractive in methods
      assert :mmr in methods
    end
  end

  describe "EntityRecognizerAdapter" do
    test "recognize_document/2 extracts entities from document" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 40}, 40)

      tokens = [
        %Token{text: "Apple", pos_tag: :propn, language: :en, span: span},
        %Token{text: "Inc", pos_tag: :propn, language: :en, span: span},
        %Token{text: ".", pos_tag: :punct, language: :en, span: span},
        %Token{text: "is", pos_tag: :aux, language: :en, span: span},
        %Token{text: "located", pos_tag: :verb, language: :en, span: span},
        %Token{text: "in", pos_tag: :adp, language: :en, span: span},
        %Token{text: "California", pos_tag: :propn, language: :en, span: span},
        %Token{text: ".", pos_tag: :punct, language: :en, span: span}
      ]

      clause = %Nasty.AST.Clause{
        type: :independent,
        predicate: %Nasty.AST.VerbPhrase{
          head: Enum.at(tokens, 4),
          language: :en,
          span: span
        },
        language: :en,
        span: span
      }

      sentence = %Sentence{
        function: :declarative,
        structure: :simple,
        main_clause: clause,
        language: :en,
        span: span
      }

      doc = %Document{
        language: :en,
        span: span,
        paragraphs: [
          %Paragraph{
            sentences: [sentence],
            language: :en,
            span: span
          }
        ]
      }

      assert {:ok, entities} = EntityRecognizerAdapter.recognize_document(doc, [])
      assert is_list(entities)
      assert Enum.all?(entities, &match?(%Entity{}, &1))
    end

    test "recognize_sentence/2 extracts entities from sentence" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)
      token_work = %Token{text: "works", pos_tag: :verb, language: :en, span: span}

      clause = %Nasty.AST.Clause{
        type: :independent,
        predicate: %Nasty.AST.VerbPhrase{
          head: token_work,
          language: :en,
          span: span
        },
        language: :en,
        span: span
      }

      sentence = %Sentence{
        function: :declarative,
        structure: :simple,
        main_clause: clause,
        language: :en,
        span: span
      }

      assert {:ok, entities} = EntityRecognizerAdapter.recognize_sentence(sentence, [])
      assert is_list(entities)
    end

    test "recognize/2 extracts entities from token list" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)

      tokens = [
        %Token{text: "Microsoft", pos_tag: :propn, language: :en, span: span},
        %Token{text: "released", pos_tag: :verb, language: :en, span: span},
        %Token{text: "Windows", pos_tag: :propn, language: :en, span: span}
      ]

      assert {:ok, entities} = EntityRecognizerAdapter.recognize(tokens, [])
      assert is_list(entities)
    end

    test "supported_types/0 returns all entity types" do
      types = EntityRecognizerAdapter.supported_types()
      assert is_list(types)
      # The adapter returns lowercase entity types matching the English implementation
      assert :person in types
      assert :org in types
      assert :gpe in types
      assert :date in types
      assert :money in types
      assert :percent in types
    end
  end

  describe "CoreferenceResolverAdapter" do
    test "resolve/2 resolves coreferences in document" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 20}, 20)
      token = %Token{text: "went", pos_tag: :verb, language: :en, span: span}

      clause = %Nasty.AST.Clause{
        type: :independent,
        predicate: %Nasty.AST.VerbPhrase{
          head: token,
          language: :en,
          span: span
        },
        language: :en,
        span: span
      }

      sentence1 = %Sentence{
        function: :declarative,
        structure: :simple,
        main_clause: clause,
        language: :en,
        span: span
      }

      sentence2 = %Sentence{
        function: :declarative,
        structure: :simple,
        main_clause: clause,
        language: :en,
        span: span
      }

      doc = %Document{
        language: :en,
        span: span,
        paragraphs: [
          %Paragraph{
            sentences: [sentence1, sentence2],
            language: :en,
            span: span
          }
        ]
      }

      assert {:ok, resolved_doc} = CoreferenceResolverAdapter.resolve(doc, [])
      assert %Document{} = resolved_doc
    end

    test "algorithms/0 returns available coreference algorithms" do
      algorithms = CoreferenceResolverAdapter.algorithms()
      assert is_list(algorithms)
      assert :rule_based in algorithms
    end
  end
end
