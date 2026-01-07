defmodule Nasty.Statistics.Neural.Architectures.BiLSTMCRFTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Architectures.BiLSTMCRF

  describe "build/1" do
    test "builds model with required parameters" do
      config = %{
        vocab_size: 1000,
        embedding_dim: 100,
        hidden_size: 128,
        num_tags: 17
      }

      model = BiLSTMCRF.build(config)

      assert %Axon{} = model
    end

    test "builds model with character CNN enabled" do
      config = %{
        vocab_size: 1000,
        embedding_dim: 100,
        hidden_size: 128,
        num_tags: 17,
        use_char_cnn: true,
        char_vocab_size: 100,
        char_embedding_dim: 25
      }

      model = BiLSTMCRF.build(config)

      assert %Axon{} = model
    end

    test "builds model with custom number of LSTM layers" do
      config = %{
        vocab_size: 1000,
        embedding_dim: 100,
        hidden_size: 128,
        num_tags: 17,
        num_lstm_layers: 3
      }

      model = BiLSTMCRF.build(config)

      assert %Axon{} = model
    end

    test "builds model with dropout" do
      config = %{
        vocab_size: 1000,
        embedding_dim: 100,
        hidden_size: 128,
        num_tags: 17,
        dropout: 0.5
      }

      model = BiLSTMCRF.build(config)

      assert %Axon{} = model
    end

    test "builds model with pre-trained embeddings" do
      # Create a simple embedding matrix
      {embeddings, _key} = Nx.Random.uniform(Nx.Random.key(42), shape: {1000, 100})

      config = %{
        vocab_size: 1000,
        embedding_dim: 100,
        hidden_size: 128,
        num_tags: 17,
        pretrained_embeddings: embeddings
      }

      model = BiLSTMCRF.build(config)

      assert %Axon{} = model
    end
  end

  describe "default_config/1" do
    test "returns default configuration" do
      config = BiLSTMCRF.default_config()

      assert config.embedding_dim == 300
      assert config.hidden_size == 256
      assert config.num_lstm_layers == 2
      assert config.dropout == 0.3
      assert config.use_char_cnn == false
    end

    test "merges custom options with defaults" do
      config =
        BiLSTMCRF.default_config(
          vocab_size: 5000,
          hidden_size: 512,
          custom_key: "value"
        )

      assert config.vocab_size == 5000
      assert config.hidden_size == 512
      assert config.custom_key == "value"
      # default preserved
      assert config.embedding_dim == 300
    end
  end

  describe "pos_tagging_config/1" do
    test "returns POS tagging configuration" do
      config =
        BiLSTMCRF.pos_tagging_config(
          vocab_size: 10_000,
          num_tags: 17
        )

      assert config.vocab_size == 10_000
      assert config.num_tags == 17
      assert config.hidden_size == 256
      assert config.use_char_cnn == true
    end

    test "enables character CNN by default" do
      config =
        BiLSTMCRF.pos_tagging_config(
          vocab_size: 10_000,
          num_tags: 17
        )

      assert config.use_char_cnn == true
      assert Map.has_key?(config, :char_vocab_size)
      assert Map.has_key?(config, :char_embedding_dim)
    end
  end

  describe "ner_config/1" do
    test "returns NER configuration" do
      config =
        BiLSTMCRF.ner_config(
          vocab_size: 10_000,
          num_tags: 9
        )

      assert config.vocab_size == 10_000
      assert config.num_tags == 9
      assert config.hidden_size == 256
      assert config.use_char_cnn == true
    end
  end

  describe "dependency_parsing_config/1" do
    test "returns dependency parsing configuration" do
      config =
        BiLSTMCRF.dependency_parsing_config(
          vocab_size: 10_000,
          num_tags: 45
        )

      assert config.vocab_size == 10_000
      assert config.num_tags == 45
      assert config.hidden_size == 512
      assert config.num_lstm_layers == 3
    end

    test "uses deeper architecture" do
      config =
        BiLSTMCRF.dependency_parsing_config(
          vocab_size: 10_000,
          num_tags: 45
        )

      assert config.num_lstm_layers == 3
      assert config.hidden_size == 512
    end
  end
end
