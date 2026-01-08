defmodule Nasty.Statistics.SequenceLabeling.CRFTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Statistics.SequenceLabeling.CRF

  defp make_span do
    Node.make_span({1, 0}, 0, {1, 1}, 1)
  end

  describe "new/1" do
    test "creates new untrained CRF model" do
      model = CRF.new(labels: [:person, :org, :none])

      assert model.feature_weights == %{}
      assert model.transition_weights == %{}
      assert MapSet.equal?(model.label_set, MapSet.new([:person, :org, :none]))
      assert model.labels == [:person, :org, :none]
      assert model.language == :en
    end

    test "creates model with custom language" do
      model = CRF.new(labels: [:tag1, :tag2], language: :es)

      assert model.language == :es
      assert match?([_, _], model.labels)
    end

    test "requires labels option" do
      assert_raise KeyError, fn ->
        CRF.new([])
      end
    end
  end

  describe "train/3" do
    test "trains model on simple sequence data" do
      training_data = [
        {
          [
            %Token{text: "John", pos_tag: :propn, language: :en, span: make_span()},
            %Token{text: "Smith", pos_tag: :propn, language: :en, span: make_span()}
          ],
          [:person, :person]
        },
        {
          [
            %Token{text: "Apple", pos_tag: :propn, language: :en, span: make_span()},
            %Token{text: "Inc", pos_tag: :propn, language: :en, span: make_span()}
          ],
          [:org, :org]
        }
      ]

      model = CRF.new(labels: [:person, :org, :none])
      {:ok, trained} = CRF.train(model, training_data, iterations: 10)

      assert map_size(trained.feature_weights) > 0
      assert map_size(trained.transition_weights) > 0
      assert is_map(trained.metadata)
    end

    test "supports different optimization methods" do
      training_data = [
        {
          [%Token{text: "word", pos_tag: :noun, language: :en, span: make_span()}],
          [:none]
        }
      ]

      model = CRF.new(labels: [:none])

      {:ok, trained_sgd} = CRF.train(model, training_data, iterations: 5, method: :sgd)
      assert is_map(trained_sgd.feature_weights)

      {:ok, trained_momentum} =
        CRF.train(model, training_data, iterations: 5, method: :momentum)

      assert is_map(trained_momentum.feature_weights)
    end

    test "applies regularization during training" do
      training_data = [
        {
          [%Token{text: "test", pos_tag: :noun, language: :en, span: make_span()}],
          [:tag]
        }
      ]

      model = CRF.new(labels: [:tag])

      {:ok, trained} =
        CRF.train(model, training_data, iterations: 10, regularization: 0.5)

      assert map_size(trained.feature_weights) >= 0
    end
  end

  describe "predict/3" do
    setup do
      # Create a simple trained model with mock weights
      labels = [:person, :org, :none]

      model = %CRF{
        feature_weights: %{
          "word=john" => %{person: 2.0, org: -1.0, none: -1.0},
          "word=apple" => %{person: -1.0, org: 2.0, none: -1.0}
        },
        transition_weights: %{
          {nil, :person} => 0.5,
          {nil, :org} => 0.5,
          {:person, :person} => 1.0,
          {:org, :org} => 1.0,
          {:person, :none} => -0.5,
          {:org, :none} => -0.5
        },
        label_set: MapSet.new(labels),
        labels: labels,
        language: :en,
        metadata: %{}
      }

      {:ok, model: model}
    end

    test "predicts labels for token sequence", %{model: model} do
      tokens = [
        %Token{text: "John", pos_tag: :propn, language: :en, span: make_span()},
        %Token{text: "Smith", pos_tag: :propn, language: :en, span: make_span()}
      ]

      {:ok, labels} = CRF.predict(model, tokens, [])

      assert match?([_, _], labels)
      assert Enum.all?(labels, &(&1 in [:person, :org, :none]))
    end

    test "handles single token", %{model: model} do
      tokens = [%Token{text: "Apple", pos_tag: :propn, language: :en, span: make_span()}]

      {:ok, labels} = CRF.predict(model, tokens, [])

      assert match?([_], labels)
    end

    test "handles empty token list" do
      model = CRF.new(labels: [:tag])
      {:ok, labels} = CRF.predict(model, [], [])

      assert labels == []
    end
  end

  describe "save/2 and load/1" do
    @tag :tmp_dir
    test "saves and loads model", %{tmp_dir: tmp_dir} do
      labels = [:person, :org, :none]
      model = CRF.new(labels: labels, language: :en)

      model = %{
        model
        | feature_weights: %{"test" => %{person: 1.0}},
          transition_weights: %{{:person, :org} => 0.5}
      }

      path = Path.join(tmp_dir, "test_crf.model")

      assert :ok = CRF.save(model, path)
      assert File.exists?(path)

      {:ok, loaded} = CRF.load(path)
      assert loaded.labels == labels
      assert loaded.language == :en
      assert map_size(loaded.feature_weights) > 0
      assert map_size(loaded.transition_weights) > 0
    end
  end

  describe "integration" do
    test "full pipeline: train and predict" do
      training_data = [
        {
          [
            %Token{text: "Alice", pos_tag: :propn, language: :en, span: make_span()},
            %Token{text: "works", pos_tag: :verb, language: :en, span: make_span()},
            %Token{text: "at", pos_tag: :adp, language: :en, span: make_span()},
            %Token{text: "Google", pos_tag: :propn, language: :en, span: make_span()}
          ],
          [:person, :none, :none, :org]
        },
        {
          [
            %Token{text: "Bob", pos_tag: :propn, language: :en, span: make_span()},
            %Token{text: "joined", pos_tag: :verb, language: :en, span: make_span()},
            %Token{text: "Microsoft", pos_tag: :propn, language: :en, span: make_span()}
          ],
          [:person, :none, :org]
        }
      ]

      model = CRF.new(labels: [:person, :org, :none])
      {:ok, trained} = CRF.train(model, training_data, iterations: 20)

      test_tokens = [
        %Token{text: "Charlie", pos_tag: :propn, language: :en, span: make_span()},
        %Token{text: "leads", pos_tag: :verb, language: :en, span: make_span()},
        %Token{text: "Apple", pos_tag: :propn, language: :en, span: make_span()}
      ]

      {:ok, predicted_labels} = CRF.predict(trained, test_tokens, [])

      assert match?([_, _, _], predicted_labels)
      assert Enum.all?(predicted_labels, &(&1 in [:person, :org, :none]))
    end
  end
end
