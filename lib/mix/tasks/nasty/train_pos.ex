defmodule Mix.Tasks.Nasty.Train.Pos do
  @shortdoc "Train a POS tagging model"

  @moduledoc """
  Trains a Hidden Markov Model for part-of-speech tagging.

  ## Usage

      mix nasty.train.pos --corpus TRAIN_FILE [options]

  ## Options

      --corpus PATH       Path to CoNLL-U training file (required)
      --dev PATH          Path to development/validation file (optional)
      --test PATH         Path to test file (optional)
      --output PATH       Output path for trained model (default: priv/models/en/pos_hmm_v1.model)
      --smoothing FLOAT   Smoothing constant for unknown words (default: 0.001)
      --quiet             Suppress progress output

  ## Examples

      # Basic training
      mix nasty.train.pos --corpus data/UD_English-EWT/en_ewt-ud-train.conllu

      # Training with evaluation
      mix nasty.train.pos \\
        --corpus data/UD_English-EWT/en_ewt-ud-train.conllu \\
        --dev data/UD_English-EWT/en_ewt-ud-dev.conllu \\
        --test data/UD_English-EWT/en_ewt-ud-test.conllu

      # Custom output location and hyperparameters
      mix nasty.train.pos \\
        --corpus train.conllu \\
        --output my_model.model \\
        --smoothing 0.0005

  ## Output

  The task creates two files:
  - `{output_path}` - The trained model (binary format)
  - `{output_path}.meta.json` - Model metadata (JSON format)

  The metadata file includes:
  - Model type, version, and training parameters
  - Training corpus information
  - Evaluation metrics (accuracy, F1 score)
  - Vocabulary and tag statistics
  """

  use Mix.Task
  alias Nasty.Data.Corpus
  alias Nasty.Statistics.Evaluator
  alias Nasty.Statistics.POSTagging.HMMTagger

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:ok, opts} ->
        run_training(opts)

      {:error, reason} ->
        Mix.shell().error("Error: #{reason}")
        Mix.shell().info("")
        Mix.shell().info("Usage: mix nasty.train.pos --corpus TRAIN_FILE [options]")
        Mix.shell().info("Use --help for more information")
        exit({:shutdown, 1})
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
          quiet: :boolean
        ]
      )

    if parsed[:corpus] do
      {:ok,
       %{
         corpus: parsed[:corpus],
         dev: parsed[:dev],
         test: parsed[:test],
         output: parsed[:output] || "priv/models/en/pos_hmm_v1.model",
         smoothing: parsed[:smoothing] || 0.001,
         quiet: parsed[:quiet] || false
       }}
    else
      {:error, "Missing required argument: --corpus"}
    end
  end

  defp run_training(opts) do
    log(opts, "\n=== Nasty HMM POS Tagger Training ===\n")

    # Load training data
    log(opts, "Loading training corpus: #{opts.corpus}")

    {:ok, train_corpus} = Corpus.load_ud(opts.corpus, language: :en)
    train_data = Corpus.extract_pos_sequences(train_corpus)
    train_stats = Corpus.statistics(train_corpus)

    log(opts, "  Sentences: #{length(train_data)}")
    log(opts, "  Tokens: #{train_stats.num_tokens}")
    log(opts, "  Vocabulary: #{train_stats.num_types}")
    log(opts, "  POS tags: #{map_size(train_stats.pos_distribution)}")

    # Load dev data if provided
    {dev_data, _dev_stats} =
      if opts.dev do
        log(opts, "\nLoading dev corpus: #{opts.dev}")
        {:ok, dev_corpus} = Corpus.load_ud(opts.dev, language: :en)
        dev_sequences = Corpus.extract_pos_sequences(dev_corpus)
        dev_st = Corpus.statistics(dev_corpus)
        log(opts, "  Sentences: #{length(dev_sequences)}")
        {dev_sequences, dev_st}
      else
        {nil, nil}
      end

    # Load test data if provided
    {test_data, _test_stats} =
      if opts.test do
        log(opts, "\nLoading test corpus: #{opts.test}")
        {:ok, test_corpus} = Corpus.load_ud(opts.test, language: :en)
        test_sequences = Corpus.extract_pos_sequences(test_corpus)
        test_st = Corpus.statistics(test_corpus)
        log(opts, "  Sentences: #{length(test_sequences)}")
        {test_sequences, test_st}
      else
        {nil, nil}
      end

    # Train model
    log(opts, "\nTraining HMM model (smoothing_k=#{opts.smoothing})...")
    start_time = System.monotonic_time(:millisecond)

    model = HMMTagger.new(smoothing_k: opts.smoothing)
    {:ok, trained_model} = HMMTagger.train(model, train_data, [])

    elapsed = System.monotonic_time(:millisecond) - start_time
    log(opts, "  Training completed in #{elapsed}ms")

    # Show model info
    metadata = HMMTagger.metadata(trained_model)
    log(opts, "\nModel Statistics:")
    log(opts, "  POS tags: #{metadata.num_tags}")
    log(opts, "  Vocabulary: #{metadata.vocab_size}")
    log(opts, "  Training size: #{metadata.training_size}")

    # Evaluate on training data
    log(opts, "\n--- Training Set Evaluation ---")
    train_metrics = evaluate_model(trained_model, train_data)
    print_metrics(train_metrics, opts)

    # Evaluate on dev data if provided
    dev_metrics =
      if dev_data do
        log(opts, "\n--- Development Set Evaluation ---")
        metrics = evaluate_model(trained_model, dev_data)
        print_metrics(metrics, opts)
        metrics
      else
        nil
      end

    # Evaluate on test data if provided
    test_metrics =
      if test_data do
        log(opts, "\n--- Test Set Evaluation ---")
        metrics = evaluate_model(trained_model, test_data)
        print_metrics(metrics, opts)
        metrics
      else
        nil
      end

    # Save model
    log(opts, "\nSaving model to: #{opts.output}")
    output_dir = Path.dirname(opts.output)
    File.mkdir_p!(output_dir)

    case HMMTagger.save(trained_model, opts.output) do
      :ok ->
        file_size = File.stat!(opts.output).size
        log(opts, "  Model saved successfully (#{format_bytes(file_size)})")

      {:error, reason} ->
        Mix.shell().error("  Failed to save model: #{inspect(reason)}")
        exit({:shutdown, 1})
    end

    # Generate and save metadata
    meta_path = opts.output <> ".meta.json"
    meta_content = generate_metadata(opts, metadata, train_metrics, dev_metrics, test_metrics)

    case File.write(meta_path, :json.encode(meta_content)) do
      :ok ->
        log(opts, "  Metadata saved to: #{meta_path}")

      {:error, reason} ->
        Mix.shell().error("  Failed to save metadata: #{inspect(reason)}")
    end

    # Generate SHA256 checksum
    sha_path = opts.output <> ".sha256"
    sha256 = compute_sha256(opts.output)

    case File.write(sha_path, sha256 <> "\n") do
      :ok ->
        log(opts, "  SHA256 checksum: #{sha256}")

      {:error, reason} ->
        Mix.shell().error("  Failed to save checksum: #{inspect(reason)}")
    end

    log(opts, "\nTraining complete!")
    log(opts, "\nTo use this model:")
    log(opts, "  Nasty.parse(text, language: :en, model: :hmm)")
    log(opts, "\nOr load explicitly:")
    log(opts, "  {:ok, model} = Nasty.Statistics.POSTagging.HMMTagger.load(\"#{opts.output}\")")
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

  defp print_metrics(metrics, opts) do
    log(opts, "  Accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
    log(opts, "  Macro F1: #{Float.round(metrics.f1, 4)}")
    log(opts, "  Precision: #{Float.round(metrics.precision, 4)}")
    log(opts, "  Recall: #{Float.round(metrics.recall, 4)}")

    # Show top/bottom performing tags
    sorted_tags =
      metrics.per_class
      |> Enum.sort_by(fn {_tag, m} -> m.f1 end, :desc)

    log(opts, "\n  Top 5 tags by F1:")

    sorted_tags
    |> Enum.take(5)
    |> Enum.each(fn {tag, m} ->
      log(opts, "    #{tag}: F1=#{Float.round(m.f1, 3)} (support=#{m.support})")
    end)

    if length(sorted_tags) > 10 do
      log(opts, "\n  Bottom 5 tags by F1:")

      sorted_tags
      |> Enum.take(-5)
      |> Enum.reverse()
      |> Enum.each(fn {tag, m} ->
        log(opts, "    #{tag}: F1=#{Float.round(m.f1, 3)} (support=#{m.support})")
      end)
    end
  end

  defp generate_metadata(opts, model_meta, _train_metrics, _dev_metrics, test_metrics) do
    base = %{
      "version" => "1.0",
      "model_type" => "hmm_pos_tagger",
      "language" => "en",
      "training_date" => Date.utc_today() |> Date.to_iso8601(),
      "training_size" => model_meta.training_size,
      "vocab_size" => model_meta.vocab_size,
      "num_tags" => model_meta.num_tags,
      "hyperparameters" => %{
        "smoothing_k" => opts.smoothing
      },
      "trained_on" => Path.basename(opts.corpus),
      "file_size_bytes" => File.stat!(opts.output).size,
      "sha256" => compute_sha256(opts.output)
    }

    if test_metrics do
      Map.merge(base, %{
        "test_accuracy" => test_metrics.accuracy,
        "test_f1" => test_metrics.f1
      })
    else
      base
    end
  end

  defp compute_sha256(path) do
    File.stream!(path, [], 2048)
    |> Enum.reduce(:crypto.hash_init(:sha256), fn chunk, acc ->
      :crypto.hash_update(acc, chunk)
    end)
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"

  defp log(%{quiet: true}, _message), do: :ok
  defp log(_opts, message), do: Mix.shell().info(message)
end
