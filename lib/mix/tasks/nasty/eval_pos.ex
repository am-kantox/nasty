defmodule Mix.Tasks.Nasty.Eval.Pos do
  @shortdoc "Evaluate a POS tagging model"

  @moduledoc """
  Evaluates a trained POS tagging model on test data.

  ## Usage

      mix nasty.eval.pos --model MODEL_PATH --test TEST_FILE [options]

  ## Options

      --model PATH        Path to trained model file (required)
      --test PATH         Path to CoNLL-U test file (required)
      --baseline          Also evaluate rule-based baseline for comparison

  ## Examples

      # Evaluate a trained model
      mix nasty.eval.pos \\
        --model priv/models/en/pos_hmm_v1.model \\
        --test data/UD_English-EWT/en_ewt-ud-test.conllu

      # Compare with rule-based baseline
      mix nasty.eval.pos \\
        --model priv/models/en/pos_hmm_v1.model \\
        --test data/UD_English-EWT/en_ewt-ud-test.conllu \\
        --baseline

  ## Output

  The task reports:
  - Overall accuracy
  - Macro-averaged F1, precision, and recall
  - Per-class performance for each POS tag
  - Top and bottom performing tags
  - Confusion matrix (optional)

  If --baseline is provided, compares the model against rule-based tagging.
  """

  use Mix.Task
  alias Nasty.Data.Corpus
  alias Nasty.Language.English.POSTagger, as: RulePOSTagger
  alias Nasty.Statistics.Evaluator
  alias Nasty.Statistics.POSTagging.HMMTagger

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:ok, opts} ->
        run_evaluation(opts)

      {:error, reason} ->
        Mix.shell().error("Error: #{reason}")
        Mix.shell().info("")
        Mix.shell().info("Usage: mix nasty.eval.pos --model MODEL_PATH --test TEST_FILE")
        exit({:shutdown, 1})
    end
  end

  defp parse_args(args) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          model: :string,
          test: :string,
          baseline: :boolean
        ]
      )

    cond do
      !parsed[:model] ->
        {:error, "Missing required argument: --model"}

      !parsed[:test] ->
        {:error, "Missing required argument: --test"}

      true ->
        {:ok,
         %{
           model: parsed[:model],
           test: parsed[:test],
           baseline: parsed[:baseline] || false
         }}
    end
  end

  defp run_evaluation(opts) do
    Mix.shell().info("\n=== POS Tagger Evaluation ===\n")

    # Load model
    Mix.shell().info("Loading model: #{opts.model}")

    {:ok, model} =
      case HMMTagger.load(opts.model) do
        {:ok, m} ->
          {:ok, m}

        {:error, reason} ->
          Mix.shell().error("Failed to load model: #{inspect(reason)}")
          exit({:shutdown, 1})
      end

    Mix.shell().info("  Model loaded successfully")

    # Load test data
    Mix.shell().info("\nLoading test corpus: #{opts.test}")
    {:ok, test_corpus} = Corpus.load_ud(opts.test, language: :en)
    test_data = Corpus.extract_pos_sequences(test_corpus)
    test_stats = Corpus.statistics(test_corpus)

    Mix.shell().info("  Sentences: #{length(test_data)}")
    Mix.shell().info("  Tokens: #{test_stats.num_tokens}")
    Mix.shell().info("  Vocabulary: #{test_stats.num_types}")

    # Evaluate HMM model
    Mix.shell().info("\n--- HMM Model Evaluation ---")
    hmm_metrics = evaluate_hmm_model(model, test_data)
    print_metrics(hmm_metrics)

    # Evaluate baseline if requested
    if opts.baseline do
      Mix.shell().info("\n--- Rule-based Baseline Evaluation ---")
      baseline_metrics = evaluate_baseline(test_data)
      print_metrics(baseline_metrics)

      # Print comparison
      Mix.shell().info("\n--- Comparison ---")

      accuracy_diff = hmm_metrics.accuracy - baseline_metrics.accuracy
      f1_diff = hmm_metrics.f1 - baseline_metrics.f1

      Mix.shell().info("  HMM Accuracy: #{Float.round(hmm_metrics.accuracy * 100, 2)}%")

      Mix.shell().info("  Baseline Accuracy: #{Float.round(baseline_metrics.accuracy * 100, 2)}%")

      Mix.shell().info("  Improvement: #{format_diff(accuracy_diff * 100)}% (absolute)")

      Mix.shell().info("")
      Mix.shell().info("  HMM F1: #{Float.round(hmm_metrics.f1, 4)}")
      Mix.shell().info("  Baseline F1: #{Float.round(baseline_metrics.f1, 4)}")
      Mix.shell().info("  Improvement: #{format_diff(f1_diff)}")
    end

    Mix.shell().info("\nEvaluation complete!")
  end

  defp evaluate_hmm_model(model, test_data) do
    predictions =
      Enum.map(test_data, fn {words, gold_tags} ->
        {:ok, pred_tags} = HMMTagger.predict(model, words, [])
        {gold_tags, pred_tags}
      end)

    gold = predictions |> Enum.flat_map(&elem(&1, 0))
    pred = predictions |> Enum.flat_map(&elem(&1, 1))

    Evaluator.classification_metrics(gold, pred)
  end

  defp evaluate_baseline(test_data) do
    predictions =
      Enum.map(test_data, fn {words, gold_tags} ->
        # Create minimal tokens for rule-based tagging
        tokens =
          Enum.map(words, fn word ->
            span = %{
              start_pos: {1, 1},
              end_pos: {1, 1},
              start_offset: 0,
              end_offset: 0
            }

            %Nasty.AST.Token{
              text: word,
              pos_tag: :noun,
              lemma: nil,
              morphology: %{},
              span: span,
              language: :en
            }
          end)

        {:ok, tagged} = RulePOSTagger.tag_pos_rule_based(tokens)
        pred_tags = Enum.map(tagged, & &1.pos_tag)

        {gold_tags, pred_tags}
      end)

    gold = predictions |> Enum.flat_map(&elem(&1, 0))
    pred = predictions |> Enum.flat_map(&elem(&1, 1))

    Evaluator.classification_metrics(gold, pred)
  end

  defp print_metrics(metrics) do
    Mix.shell().info("  Accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
    Mix.shell().info("  Macro F1: #{Float.round(metrics.f1, 4)}")
    Mix.shell().info("  Precision: #{Float.round(metrics.precision, 4)}")
    Mix.shell().info("  Recall: #{Float.round(metrics.recall, 4)}")

    # Show top/bottom performing tags
    sorted_tags =
      metrics.per_class
      |> Enum.sort_by(fn {_tag, m} -> m.f1 end, :desc)

    Mix.shell().info("\n  Top 5 tags by F1:")

    sorted_tags
    |> Enum.take(5)
    |> Enum.each(fn {tag, m} ->
      Mix.shell().info("    #{tag}: F1=#{Float.round(m.f1, 3)} (support=#{m.support})")
    end)

    if length(sorted_tags) > 10 do
      Mix.shell().info("\n  Bottom 5 tags by F1:")

      sorted_tags
      |> Enum.take(-5)
      |> Enum.reverse()
      |> Enum.each(fn {tag, m} ->
        Mix.shell().info("    #{tag}: F1=#{Float.round(m.f1, 3)} (support=#{m.support})")
      end)
    end
  end

  defp format_diff(diff) when diff > 0, do: "+#{Float.round(diff, 4)}"
  defp format_diff(diff), do: Float.round(diff, 4)
end
