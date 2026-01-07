defmodule Mix.Tasks.Nasty.Train.NeuralPos do
  @moduledoc """
  Train a neural POS tagger on Universal Dependencies corpus.

  ## Usage

      mix nasty.train.neural_pos --corpus path/to/en_ewt-ud-train.conllu [OPTIONS]

  ## Options

    * `--corpus` - Path to CoNLL-U training corpus (required)
    * `--test-corpus` - Path to test corpus (optional)
    * `--output` - Output model path (default: priv/models/en/pos_neural_v1.axon)
    * `--epochs` - Number of training epochs (default: 10)
    * `--batch-size` - Batch size (default: 32)
    * `--learning-rate` - Learning rate (default: 0.001)
    * `--hidden-size` - LSTM hidden size (default: 256)
    * `--num-layers` - Number of BiLSTM layers (default: 2)
    * `--embedding-dim` - Embedding dimension (default: 300)
    * `--dropout` - Dropout rate (default: 0.3)
    * `--validation-split` - Validation split ratio (default: 0.1)
    * `--early-stopping` - Enable early stopping (default: true)
    * `--patience` - Early stopping patience (default: 3)
    * `--embeddings` - Path to pre-trained embeddings (GloVe format, optional)
    * `--use-char-cnn` - Use character-level CNN (default: false)
    * `--max-sentences` - Maximum training sentences (default: unlimited)

  ## Examples

      # Train on UD English corpus
      mix nasty.train.neural_pos --corpus data/en_ewt-ud-train.conllu

      # Train with custom hyperparameters
      mix nasty.train.neural_pos \\
        --corpus data/train.conllu \\
        --test-corpus data/test.conllu \\
        --epochs 15 \\
        --hidden-size 384 \\
        --use-char-cnn

      # Train with pre-trained embeddings
      mix nasty.train.neural_pos \\
        --corpus data/train.conllu \\
        --embeddings glove.6B.300d.txt

  ## Output

  The trained model will be saved to the specified output path along with:
  - Model file (.axon)
  - Metadata file (.meta.json)
  - Training log

  ## Performance

  Expected training time on UD English (12k sentences):
  - CPU: ~30-60 minutes
  - GPU (EXLA): ~5-10 minutes

  Expected accuracy: 97-98% on standard benchmarks
  """

  @shortdoc "Train a neural POS tagger"

  use Mix.Task

  alias Nasty.Statistics.{Evaluator, Neural.DataLoader, POSTagging.NeuralTagger}
  require Logger

  @impl Mix.Task
  def run(args) do
    # Start applications
    {:ok, _} = Application.ensure_all_started(:nasty)

    # Parse options
    opts = parse_args(args)

    # Validate required arguments
    unless opts[:corpus] do
      Mix.raise("--corpus option is required")
    end

    Mix.shell().info("=== Neural POS Tagger Training ===\n")
    Mix.shell().info("Configuration:")
    print_config(opts)
    Mix.shell().info("")

    # Load training data
    Mix.shell().info("Loading training corpus...")
    {:ok, train_sentences} = DataLoader.load_conllu(opts[:corpus], opts)

    # Analyze corpus
    stats = DataLoader.analyze(train_sentences)
    Mix.shell().info("Corpus statistics:")
    Mix.shell().info("  Sentences: #{stats.num_sentences}")
    Mix.shell().info("  Tokens: #{stats.num_tokens}")
    Mix.shell().info("  Avg length: #{Float.round(stats.avg_length, 1)}")
    Mix.shell().info("  Vocab size: #{stats.vocab_size}")
    Mix.shell().info("")

    # Split data
    validation_split = opts[:validation_split]

    {train_data, valid_data} =
      DataLoader.split(train_sentences, [1.0 - validation_split, validation_split])

    Mix.shell().info("Data split:")
    Mix.shell().info("  Training: #{length(train_data)} sentences")
    Mix.shell().info("  Validation: #{length(valid_data)} sentences")
    Mix.shell().info("")

    # Build vocabularies
    Mix.shell().info("Building vocabularies...")
    {:ok, vocab, tag_vocab} = DataLoader.build_vocabularies(train_data, min_freq: 2)
    Mix.shell().info("  Word vocabulary: #{vocab.size} words")
    Mix.shell().info("  Tag vocabulary: #{tag_vocab.size} tags")
    Mix.shell().info("")

    # Create neural tagger
    Mix.shell().info("Creating neural model...")

    tagger =
      NeuralTagger.new(
        vocab: vocab,
        tag_vocab: tag_vocab,
        embedding_dim: opts[:embedding_dim],
        hidden_size: opts[:hidden_size],
        num_layers: opts[:num_layers],
        dropout: opts[:dropout],
        use_char_cnn: opts[:use_char_cnn]
      )

    Mix.shell().info("Model architecture: BiLSTM-CRF")
    Mix.shell().info("  Vocabulary: #{vocab.size}")
    Mix.shell().info("  Tags: #{tag_vocab.size}")
    Mix.shell().info("  Embedding dim: #{opts[:embedding_dim]}")
    Mix.shell().info("  Hidden size: #{opts[:hidden_size]}")
    Mix.shell().info("  Layers: #{opts[:num_layers]}")
    Mix.shell().info("  Dropout: #{opts[:dropout]}")
    Mix.shell().info("")

    # Train model
    Mix.shell().info("Starting training...")
    Mix.shell().info("This may take several minutes. EXLA will compile the model on first run.")
    Mix.shell().info("")

    training_opts = [
      epochs: opts[:epochs],
      batch_size: opts[:batch_size],
      learning_rate: opts[:learning_rate],
      validation_split: 0.0,
      # Already split
      early_stopping: build_early_stopping_opts(opts)
    ]

    case NeuralTagger.train(tagger, train_data, training_opts) do
      {:ok, trained_tagger} ->
        Mix.shell().info("\nTraining completed!")

        # Evaluate on validation set
        if match?([_ | _], valid_data) do
          Mix.shell().info("\nEvaluating on validation set...")
          evaluate_model(trained_tagger, valid_data)
        end

        # Evaluate on test set if provided
        if opts[:test_corpus] do
          Mix.shell().info("\nLoading test corpus...")
          {:ok, test_sentences} = DataLoader.load_conllu(opts[:test_corpus], opts)
          Mix.shell().info("Test set: #{length(test_sentences)} sentences")

          Mix.shell().info("Evaluating on test set...")
          evaluate_model(trained_tagger, test_sentences)
        end

        # Save model
        output_path = opts[:output]
        Mix.shell().info("\nSaving model to #{output_path}...")

        case NeuralTagger.save(trained_tagger, output_path) do
          :ok ->
            Mix.shell().info("Model saved successfully!")
            Mix.shell().info("\nTraining complete!")
            Mix.shell().info("\nTo use the model:")
            Mix.shell().info("  {:ok, model} = NeuralTagger.load(\"#{output_path}\")")
            Mix.shell().info("  {:ok, tags} = NeuralTagger.predict(model, words, [])")

          {:error, reason} ->
            Mix.shell().error("Failed to save model: #{inspect(reason)}")
        end

      {:error, reason} ->
        Mix.shell().error("Training failed: #{inspect(reason)}")
        Mix.raise("Training failed")
    end
  end

  ## Private Functions

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          corpus: :string,
          test_corpus: :string,
          output: :string,
          epochs: :integer,
          batch_size: :integer,
          learning_rate: :float,
          hidden_size: :integer,
          num_layers: :integer,
          embedding_dim: :integer,
          dropout: :float,
          validation_split: :float,
          early_stopping: :boolean,
          patience: :integer,
          embeddings: :string,
          use_char_cnn: :boolean,
          max_sentences: :integer
        ]
      )

    # Set defaults
    [
      corpus: opts[:corpus],
      test_corpus: opts[:test_corpus],
      output: opts[:output] || "priv/models/en/pos_neural_v1.axon",
      epochs: opts[:epochs] || 10,
      batch_size: opts[:batch_size] || 32,
      learning_rate: opts[:learning_rate] || 0.001,
      hidden_size: opts[:hidden_size] || 256,
      num_layers: opts[:num_layers] || 2,
      embedding_dim: opts[:embedding_dim] || 300,
      dropout: opts[:dropout] || 0.3,
      validation_split: opts[:validation_split] || 0.1,
      early_stopping: opts[:early_stopping] != false,
      patience: opts[:patience] || 3,
      embeddings: opts[:embeddings],
      use_char_cnn: opts[:use_char_cnn] || false,
      max_sentences: opts[:max_sentences] || :infinity
    ]
  end

  defp print_config(opts) do
    Mix.shell().info("  Corpus: #{opts[:corpus]}")

    if opts[:test_corpus] do
      Mix.shell().info("  Test corpus: #{opts[:test_corpus]}")
    end

    Mix.shell().info("  Output: #{opts[:output]}")
    Mix.shell().info("  Epochs: #{opts[:epochs]}")
    Mix.shell().info("  Batch size: #{opts[:batch_size]}")
    Mix.shell().info("  Learning rate: #{opts[:learning_rate]}")
    Mix.shell().info("  Hidden size: #{opts[:hidden_size]}")
    Mix.shell().info("  Layers: #{opts[:num_layers]}")
    Mix.shell().info("  Embedding dim: #{opts[:embedding_dim]}")
    Mix.shell().info("  Dropout: #{opts[:dropout]}")
    Mix.shell().info("  Validation split: #{opts[:validation_split]}")
    Mix.shell().info("  Early stopping: #{opts[:early_stopping]}")

    if opts[:early_stopping] do
      Mix.shell().info("  Patience: #{opts[:patience]}")
    end

    if opts[:embeddings] do
      Mix.shell().info("  Pre-trained embeddings: #{opts[:embeddings]}")
    end

    Mix.shell().info("  Character CNN: #{opts[:use_char_cnn]}")
  end

  defp build_early_stopping_opts(opts) do
    if opts[:early_stopping] do
      [patience: opts[:patience], min_delta: 0.001]
    else
      nil
    end
  end

  defp evaluate_model(tagger, test_sentences) do
    # Extract gold tags
    gold_tags = Enum.flat_map(test_sentences, fn {_words, tags} -> tags end)

    # Predict
    predicted_tags =
      Enum.flat_map(test_sentences, fn {words, _tags} ->
        case NeuralTagger.predict(tagger, words, []) do
          {:ok, tags} -> tags
          {:error, _} -> List.duplicate(:noun, length(words))
        end
      end)

    # Calculate metrics
    metrics = Evaluator.classification_metrics(gold_tags, predicted_tags)

    Mix.shell().info("\nResults:")
    Mix.shell().info("  Accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
    Mix.shell().info("  Precision: #{Float.round(metrics.precision, 4)}")
    Mix.shell().info("  Recall: #{Float.round(metrics.recall, 4)}")
    Mix.shell().info("  F1 Score: #{Float.round(metrics.f1, 4)}")

    # Show per-tag metrics for common tags
    Mix.shell().info("\nPer-tag metrics (top tags):")

    metrics.per_class
    |> Enum.sort_by(fn {_tag, m} -> -m.support end)
    |> Enum.take(10)
    |> Enum.each(fn {tag, m} ->
      Mix.shell().info(
        "  #{String.pad_trailing(to_string(tag), 8)} P=#{Float.round(m.precision, 3)} R=#{Float.round(m.recall, 3)} F1=#{Float.round(m.f1, 3)} (#{m.support})"
      )
    end)
  end
end
