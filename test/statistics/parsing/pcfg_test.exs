defmodule Nasty.Statistics.Parsing.PCFGTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.Token
  alias Nasty.Statistics.Parsing.{Grammar, PCFG}
  alias Nasty.Statistics.Parsing.Grammar.Rule

  describe "new/1" do
    test "creates new untrained PCFG model with defaults" do
      model = PCFG.new()

      assert model.rules == []
      assert model.rule_index == %{}
      assert model.lexicon == %{}
      assert MapSet.size(model.non_terminals) == 0
      assert model.start_symbol == :s
      assert model.smoothing_k == 0.001
      assert model.language == :en
    end

    test "creates model with custom options" do
      model = PCFG.new(start_symbol: :root, smoothing_k: 0.01, language: :es)

      assert model.start_symbol == :root
      assert model.smoothing_k == 0.01
      assert model.language == :es
    end
  end

  describe "train/3" do
    test "trains model on simple grammar rules" do
      training_data = [
        {
          [
            %Token{span: nil, text: "the", pos_tag: :det, language: :en},
            %Token{span: nil, text: "cat", pos_tag: :noun, language: :en}
          ],
          {:s, [{:np, [{:det, "the"}, {:noun, "cat"}]}]}
        },
        {
          [
            %Token{span: nil, text: "the", pos_tag: :det, language: :en},
            %Token{span: nil, text: "dog", pos_tag: :noun, language: :en}
          ],
          {:s, [{:np, [{:det, "the"}, {:noun, "dog"}]}]}
        }
      ]

      model = PCFG.new()
      {:ok, trained} = PCFG.train(model, training_data)

      refute Enum.empty?(trained.rules)
      assert MapSet.size(trained.non_terminals) > 0
      assert map_size(trained.lexicon) > 0
      assert trained.metadata.training_size == 2
    end

    test "applies smoothing during training" do
      training_data = [
        {
          [%Token{span: nil, text: "word", pos_tag: :noun, language: :en}],
          {:s, [{:noun, "word"}]}
        }
      ]

      model = PCFG.new(smoothing_k: 0.1)
      {:ok, trained} = PCFG.train(model, training_data, smoothing: 0.1)

      assert trained.smoothing_k == 0.1
    end

    test "converts grammar to CNF when requested" do
      training_data = [
        {
          [%Token{span: nil, text: "word", pos_tag: :noun, language: :en}],
          {:s, [{:noun, "word"}]}
        }
      ]

      model = PCFG.new()
      {:ok, trained} = PCFG.train(model, training_data, cnf: true)

      assert trained.metadata.cnf == true
    end
  end

  describe "predict/3" do
    setup do
      # Create a simple trained model
      rules = [
        %Rule{lhs: :s, rhs: [:np], probability: 1.0},
        %Rule{lhs: :np, rhs: [:det, :noun], probability: 1.0},
        %Rule{lhs: :det, rhs: ["the"], probability: 1.0},
        %Rule{lhs: :noun, rhs: ["cat"], probability: 0.5},
        %Rule{lhs: :noun, rhs: ["dog"], probability: 0.5}
      ]

      rule_index = Grammar.index_by_lhs(rules)
      non_terminals = MapSet.new([:s, :np, :det, :noun])

      lexicon = %{
        "the" => [:det],
        "cat" => [:noun],
        "dog" => [:noun]
      }

      model = %PCFG{
        rules: rules,
        rule_index: rule_index,
        lexicon: lexicon,
        non_terminals: non_terminals,
        start_symbol: :s,
        smoothing_k: 0.001,
        language: :en,
        metadata: %{}
      }

      {:ok, model: model}
    end

    test "parses valid sentence", %{model: model} do
      tokens = [
        %Token{span: nil, text: "the", pos_tag: :det, language: :en},
        %Token{span: nil, text: "cat", pos_tag: :noun, language: :en}
      ]

      {:ok, tree} = PCFG.predict(model, tokens, [])

      assert tree.label == :s
      assert is_list(tree.children)
      assert tree.probability > 0
    end

    test "returns error for unparseable sentence", %{model: model} do
      tokens = [
        %Token{span: nil, text: "unknown", pos_tag: :adj, language: :en}
      ]

      assert {:error, _reason} = PCFG.predict(model, tokens, [])
    end

    test "supports custom start symbol", %{model: model} do
      tokens = [
        %Token{span: nil, text: "the", pos_tag: :det, language: :en},
        %Token{span: nil, text: "dog", pos_tag: :noun, language: :en}
      ]

      {:ok, tree} = PCFG.predict(model, tokens, start_symbol: :s)

      assert tree.label == :s
    end
  end

  describe "save/2 and load/1" do
    @tag :tmp_dir
    test "saves and loads model", %{tmp_dir: tmp_dir} do
      model = PCFG.new(language: :en)
      path = Path.join(tmp_dir, "test.model")

      rules = [%Rule{lhs: :s, rhs: [:np], probability: 1.0}]
      model = %{model | rules: rules}

      assert :ok = PCFG.save(model, path)
      assert File.exists?(path)

      {:ok, loaded} = PCFG.load(path)
      assert loaded.language == :en
      assert length(loaded.rules) == 1
    end
  end
end
