#!/usr/bin/env elixir

# Training Script for HMM POS Tagger
#
# This script trains a Hidden Markov Model for part-of-speech tagging
# using Universal Dependencies data.
#
# Usage:
#   ./scripts/train_pos_tagger.exs [options]
#
# Options:
#   --corpus PATH      Path to CoNLL-U training file (required)
#   --dev PATH         Path to development/validation file (optional)
#   --test PATH        Path to test file (optional)
#   --output PATH      Output path for trained model (default: priv/models/en/pos_hmm.model)
#   --smoothing FLOAT  Smoothing constant (default: 0.001)
#   --help            Show this help message

alias Nasty.Statistics.POSTagging.HMMTagger
alias Nasty.Statistics.Evaluator
alias Nasty.Data.Corpus

defmodule TrainingScript do
  def main(args) do
    case parse_args(args) do
      {:ok, opts} ->
        run_training(opts)

      {:error, :help} ->
        print_help()

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        IO.puts(:stderr, "\nUse --help for usage information")
        System.halt(1)
    end
  end

  defp parse_args(args) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          corpus: :string,
          dev: :string,
          test: :string,
          output: :string,
          smoothing: :float,
          help: :boolean
        ]
      )

    cond do
      parsed[:help] ->
        {:error, :help}

      !parsed[:corpus] ->
        {:error, "Missing required argument: --corpus"}

      true ->
        {:ok,
         %{
           corpus: parsed[:corpus],
           dev: parsed[:dev],
           test: parsed[:test],
           output: parsed[:output] || "priv/models/en/pos_hmm.model",
           smoothing: parsed[:smoothing] || 0.001
         }}
    end
  end

  defp run_training(opts) do
    IO.puts("\n=== Nasty HMM POS Tagger Training ===\n")

    # Load training data
    IO.puts("Loading training corpus: #{opts.corpus}")
    {:ok, train_corpus} = Corpus.load_ud(opts.corpus, language: :en)
    train_data = Corpus.extract_pos_sequences(train_corpus)

    IO.puts("  Sentences: #{length(train_data)}")
    stats = Corpus.statistics(train_corpus)
    IO.puts("  Tokens: #{stats.num_tokens}")
    IO.puts("  Vocabulary: #{stats.num_types}")
    IO.puts("  POS tags: #{map_size(stats.pos_distribution)}")

    # Load dev data if provided
    dev_data =
      if opts.dev do
        IO.puts("\nLoading dev corpus: #{opts.dev}")
        {:ok, dev_corpus} = Corpus.load_ud(opts.dev, language: :en)
        dev_sequences = Corpus.extract_pos_sequences(dev_corpus)
        IO.puts("  Sentences: #{length(dev_sequences)}")
        dev_sequences
      else
        nil
      end

    # Train model
    IO.puts("\nTraining HMM model (smoothing_k=#{opts.smoothing})...")
    start_time = System.monotonic_time(:millisecond)

    model = HMMTagger.new(smoothing_k: opts.smoothing)
    {:ok, trained_model} = HMMTagger.train(model, train_data, [])

    elapsed = System.monotonic_time(:millisecond) - start_time
    IO.puts("  Training completed in #{elapsed}ms")

    # Show model info
    metadata = HMMTagger.metadata(trained_model)
    IO.puts("\nModel Statistics:")
    IO.puts("  POS tags: #{metadata.num_tags}")
    IO.puts("  Vocabulary: #{metadata.vocab_size}")
    IO.puts("  Training size: #{metadata.training_size}")

    # Evaluate on training data
    IO.puts("\n--- Training Set Evaluation ---")
    train_metrics = evaluate_model(trained_model, train_data)
    print_metrics(train_metrics)

    # Evaluate on dev data if provided
    if dev_data do
      IO.puts("\n--- Development Set Evaluation ---")
      dev_metrics = evaluate_model(trained_model, dev_data)
      print_metrics(dev_metrics)
    end

    # Evaluate on test data if provided
    if opts.test do
      IO.puts("\nLoading test corpus: #{opts.test}")
      {:ok, test_corpus} = Corpus.load_ud(opts.test, language: :en)
      test_data = Corpus.extract_pos_sequences(test_corpus)
      IO.puts("  Sentences: #{length(test_data)}")

      IO.puts("\n--- Test Set Evaluation ---")
      test_metrics = evaluate_model(trained_model, test_data)
      print_metrics(test_metrics)
    end

    # Save model
    IO.puts("\nSaving model to: #{opts.output}")
    output_dir = Path.dirname(opts.output)
    File.mkdir_p!(output_dir)

    case HMMTagger.save(trained_model, opts.output) do
      :ok ->
        file_size = File.stat!(opts.output).size
        IO.puts("  Model saved successfully (#{format_bytes(file_size)})")

      {:error, reason} ->
        IO.puts(:stderr, "  Failed to save model: #{inspect(reason)}")
        System.halt(1)
    end

    IO.puts("\n✓ Training complete!\n")
    IO.puts("To use this model:")
    IO.puts("  {:ok, model} = Nasty.Statistics.POSTagging.HMMTagger.load(\"#{opts.output}\")")
    IO.puts("  {:ok, ast} = Nasty.parse(text, language: :en, model: :hmm, hmm_model: model)")
  end

  defp evaluate_model(model, test_data) do
    predictions =
      Enum.map(test_data, fn {words, gold_tags} ->
        {:ok, pred_tags} = HMMTagger.predict(model, words, [])
        {gold_tags, pred_tags}
      end)

    gold = predictions |> Enum.flat_map(&elem(&1, 0))
    pred = predictions |> Enum.flat_map(&elem(&1, 1))

    Evaluator.classification_metrics(gold, pred)
  end

  defp print_metrics(metrics) do
    IO.puts("  Accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
    IO.puts("  Macro F1: #{Float.round(metrics.f1, 4)}")
    IO.puts("  Precision: #{Float.round(metrics.precision, 4)}")
    IO.puts("  Recall: #{Float.round(metrics.recall, 4)}")

    # Show top/bottom performing tags
    sorted_tags =
      metrics.per_class
      |> Enum.sort_by(fn {_tag, m} -> m.f1 end, :desc)

    IO.puts("\n  Top 5 tags by F1:")

    sorted_tags
    |> Enum.take(5)
    |> Enum.each(fn {tag, m} ->
      IO.puts("    #{tag}: F1=#{Float.round(m.f1, 3)} (support=#{m.support})")
    end)

    if length(sorted_tags) > 10 do
      IO.puts("\n  Bottom 5 tags by F1:")

      sorted_tags
      |> Enum.take(-5)
      |> Enum.reverse()
      |> Enum.each(fn {tag, m} ->
        IO.puts("    #{tag}: F1=#{Float.round(m.f1, 3)} (support=#{m.support})")
      end)
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)} KB"

  defp format_bytes(bytes),
    do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  defp print_help do
    IO.puts("""
    Nasty HMM POS Tagger Training Script

    Usage:
      ./scripts/train_pos_tagger.exs [options]

    Required Options:
      --corpus PATH      Path to CoNLL-U training file

    Optional:
      --dev PATH         Path to development/validation file
      --test PATH        Path to test file
      --output PATH      Output path for trained model
                         (default: priv/models/en/pos_hmm.model)
      --smoothing FLOAT  Smoothing constant (default: 0.001)
      --help            Show this help message

    Example:
      # Download Universal Dependencies English-EWT corpus from:
      # https://github.com/UniversalDependencies/UD_English-EWT

      ./scripts/train_pos_tagger.exs \\
        --corpus data/en_ewt-ud-train.conllu \\
        --dev data/en_ewt-ud-dev.conllu \\
        --test data/en_ewt-ud-test.conllu \\
        --output priv/models/en/pos_hmm_ewt.model

    Training Data:
      You can download Universal Dependencies treebanks from:
      https://universaldependencies.org/

      For English, we recommend:
      - UD_English-EWT (web, email, reviews, blogs)
      - UD_English-GUM (diverse genres)

    Hyperparameter Tuning:
      The --smoothing parameter controls add-k smoothing:
      - Higher values (0.01): Better for out-of-vocabulary words
      - Lower values (0.0001): Sharper distributions for known words
      - Default (0.001): Good general-purpose value

      Try different values and use --dev to find the best setting.
    """)
  end
end

TrainingScript.main(System.argv())
