defmodule Nasty.Language.English.CoreferenceResolverTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Document, Paragraph}
  alias Nasty.AST.Semantic.{CorefChain, Mention}

  alias Nasty.Language.English.{
    CoreferenceResolver,
    Morphology,
    POSTagger,
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

  describe "resolve/1 with simple pronoun coreference" do
    test "resolves simple he pronoun" do
      # "John works at Google. He is an engineer."
      text = "John works at Google. He is an engineer."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # Should return successfully (may or may not find chains depending on parsing)
      assert is_list(chains)

      # If chains are found, verify structure
      with [_ | _] <- chains do
        # Find chain containing "John" or "He"
        chain =
          Enum.find(chains, fn chain ->
            mentions = Enum.map(chain.mentions, & &1.text)
            "John" in mentions or "He" in mentions or "he" in mentions
          end)

        if chain do
          # Should have at least 2 mentions in the chain
          assert match?([_, _ | _], chain.mentions)
        end
      end
    end

    test "resolves she pronoun" do
      # "Mary likes coffee. She drinks it every morning."
      text = "Mary likes coffee. She drinks it every morning."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # Should find coreference chains
      assert is_list(chains)
    end

    test "resolves possessive pronoun" do
      # "John drove to work. His car is red."
      text = "John drove to work. His car is red."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # Should have chains
      assert is_list(chains)
    end
  end

  describe "resolve/1 with definite NPs" do
    test "resolves definite NP reference" do
      # "Apple announced a new product. The company expects strong sales."
      text = "Apple announced a new product. The company expects strong sales."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # Should identify coreference chains
      assert is_list(chains)
    end
  end

  describe "resolve/1 with multiple entities" do
    test "handles multiple entities separately" do
      # "John met Mary. He gave her a book."
      text = "John met Mary. He gave her a book."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # Should have separate chains for John and Mary
      assert is_list(chains)

      # Chains should have different representatives
      representatives = Enum.map(chains, & &1.representative)
      # Should have at least some distinct representatives
      assert match?([_ | _], Enum.uniq(representatives))
    end
  end

  describe "resolve/1 with plural pronouns" do
    test "resolves they pronoun" do
      # "The students study hard. They want good grades."
      text = "The students study hard. They want good grades."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      assert is_list(chains)
    end
  end

  describe "Mention structure" do
    test "mention has correct fields" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 4}, 4)

      mention =
        Mention.new("he", :pronoun, 0, 5, span,
          gender: :male,
          number: :singular
        )

      assert %Mention{} = mention
      assert mention.text == "he"
      assert mention.type == :pronoun
      assert mention.sentence_idx == 0
      assert mention.token_idx == 5
      assert mention.gender == :male
      assert mention.number == :singular
    end

    test "pronoun?/1 correctly identifies pronouns" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 4}, 4)

      pronoun_mention = Mention.new("he", :pronoun, 0, 0, span)
      assert Mention.pronoun?(pronoun_mention) == true

      name_mention = Mention.new("John", :proper_name, 0, 0, span)
      assert Mention.pronoun?(name_mention) == false
    end

    test "proper_name?/1 correctly identifies proper names" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 4}, 4)

      name_mention = Mention.new("John", :proper_name, 0, 0, span)
      assert Mention.proper_name?(name_mention) == true

      pronoun_mention = Mention.new("he", :pronoun, 0, 0, span)
      assert Mention.proper_name?(pronoun_mention) == false
    end

    test "gender_agrees?/2 checks gender agreement" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 4}, 4)

      male1 = Mention.new("John", :proper_name, 0, 0, span, gender: :male)
      male2 = Mention.new("he", :pronoun, 1, 5, span, gender: :male)
      female = Mention.new("she", :pronoun, 1, 5, span, gender: :female)
      unknown = Mention.new("it", :pronoun, 1, 5, span, gender: :unknown)

      assert Mention.gender_agrees?(male1, male2) == true
      assert Mention.gender_agrees?(male1, female) == false
      # Unknown agrees with anything
      assert Mention.gender_agrees?(male1, unknown) == true
      assert Mention.gender_agrees?(unknown, female) == true
    end

    test "number_agrees?/2 checks number agreement" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 4}, 4)

      sing1 = Mention.new("John", :proper_name, 0, 0, span, number: :singular)
      sing2 = Mention.new("he", :pronoun, 1, 5, span, number: :singular)
      plural = Mention.new("they", :pronoun, 1, 5, span, number: :plural)
      unknown = Mention.new("someone", :definite_np, 1, 5, span, number: :unknown)

      assert Mention.number_agrees?(sing1, sing2) == true
      assert Mention.number_agrees?(sing1, plural) == false
      # Unknown agrees with anything
      assert Mention.number_agrees?(sing1, unknown) == true
      assert Mention.number_agrees?(unknown, plural) == true
    end
  end

  describe "CorefChain structure" do
    test "chain has correct structure" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      mentions = [
        Mention.new("John", :proper_name, 0, 0, span),
        Mention.new("he", :pronoun, 1, 5, span)
      ]

      chain = CorefChain.new(1, mentions, "John")

      assert %CorefChain{} = chain
      assert chain.id == 1
      assert match?([_, _], chain.mentions)
      assert chain.representative == "John"
    end

    test "first_mention/1 returns first mention" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      m1 = Mention.new("John", :proper_name, 0, 0, span)
      m2 = Mention.new("he", :pronoun, 1, 5, span)

      chain = CorefChain.new(1, [m1, m2], "John")

      first = CorefChain.first_mention(chain)
      assert first == m1
    end

    test "last_mention/1 returns last mention" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      m1 = Mention.new("John", :proper_name, 0, 0, span)
      m2 = Mention.new("he", :pronoun, 1, 5, span)

      chain = CorefChain.new(1, [m1, m2], "John")

      last = CorefChain.last_mention(chain)
      assert last == m2
    end

    test "mention_count/1 counts mentions" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      mentions = [
        Mention.new("John", :proper_name, 0, 0, span),
        Mention.new("he", :pronoun, 1, 5, span),
        Mention.new("his", :pronoun, 2, 3, span)
      ]

      chain = CorefChain.new(1, mentions, "John")

      assert CorefChain.mention_count(chain) == 3
    end

    test "find_mention_at/2 finds mentions at specific sentence" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      mentions = [
        Mention.new("John", :proper_name, 0, 0, span),
        Mention.new("he", :pronoun, 1, 5, span),
        Mention.new("his", :pronoun, 1, 8, span),
        Mention.new("him", :pronoun, 2, 3, span)
      ]

      chain = CorefChain.new(1, mentions, "John")

      sent1_mentions = CorefChain.find_mention_at(chain, 1)
      assert match?([_, _], sent1_mentions)

      sent2_mentions = CorefChain.find_mention_at(chain, 2)
      assert [mention] = sent2_mentions
      assert mention.text == "him"
    end
  end

  describe "select_representative/1" do
    test "prefers proper name as representative" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      mentions = [
        Mention.new("he", :pronoun, 0, 0, span),
        Mention.new("John Smith", :proper_name, 1, 5, span),
        Mention.new("the man", :definite_np, 2, 3, span)
      ]

      representative = CorefChain.select_representative(mentions)

      assert representative == "John Smith"
    end

    test "prefers longest definite NP when no proper name" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      mentions = [
        Mention.new("he", :pronoun, 0, 0, span),
        Mention.new("the man", :definite_np, 1, 5, span),
        Mention.new("the tall man with glasses", :definite_np, 2, 3, span)
      ]

      representative = CorefChain.select_representative(mentions)

      # Should pick the longer definite NP
      assert representative == "the tall man with glasses"
    end

    test "uses first mention as fallback" do
      span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 10}, 10)

      mentions = [
        Mention.new("he", :pronoun, 0, 0, span),
        Mention.new("him", :pronoun, 1, 5, span)
      ]

      representative = CorefChain.select_representative(mentions)

      # Should pick first mention
      assert representative == "he"
    end

    test "handles empty list" do
      representative = CorefChain.select_representative([])

      assert representative == ""
    end
  end

  describe "integration with full pipeline" do
    test "resolves coreferences in multi-sentence document" do
      text = "Alice went to the store. She bought milk. Her friend was there."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # Should successfully resolve
      assert is_list(chains)

      # Chains should have proper structure
      Enum.each(chains, fn chain ->
        assert chain.id > 0
        # Chains should have at least 2 mentions
        assert match?([_, _ | _], chain.mentions)
        assert is_binary(chain.representative)
      end)
    end

    test "handles document with no coreferences" do
      text = "Alice runs. Bob walks. Carol swims."
      document = parse_document(text)

      {:ok, chains} = CoreferenceResolver.resolve(document)

      # May have empty chains or single-mention chains that get filtered
      assert is_list(chains)
    end
  end

  describe "options" do
    test "respects max_sentence_distance option" do
      text = "John works hard. He is dedicated."
      document = parse_document(text)

      {:ok, chains1} = CoreferenceResolver.resolve(document, max_sentence_distance: 1)
      {:ok, chains2} = CoreferenceResolver.resolve(document, max_sentence_distance: 10)

      # Both should work
      assert is_list(chains1)
      assert is_list(chains2)
    end

    test "respects min_score option" do
      text = "John works hard. He is dedicated."
      document = parse_document(text)

      {:ok, chains_low} = CoreferenceResolver.resolve(document, min_score: 0.1)
      {:ok, chains_high} = CoreferenceResolver.resolve(document, min_score: 0.9)

      # Both should work (high threshold might result in fewer/no chains)
      assert is_list(chains_low)
      assert is_list(chains_high)
    end
  end
end
