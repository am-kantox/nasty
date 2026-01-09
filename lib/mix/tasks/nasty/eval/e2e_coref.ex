defmodule Mix.Tasks.Nasty.Eval.E2eCoref do
  @moduledoc """
  Evaluate end-to-end span-based coreference resolution models.

  ## Usage

      mix nasty.eval.e2e_coref \\
        --model priv/models/en/e2e_coref \\
        --test data/ontonotes/test

  ## Options

    * `--model` - Base path to trained models (required)
    * `--test` - Path to test data directory (required)
    * `--baseline` - Compare against Phase 1 baseline (flag)
    * `--max-span-length` - Maximum span length (default: 10)
    * `--top-k-spans` - Top K spans to keep (default: 50)
    * `--min-span-score` - Minimum span score (default: 0.5)
    * `--min-coref-score` - Minimum coreference score (default: 0.5)
  """

  @shortdoc "Evaluate end-to-end coreference models"

  use Mix.Task

  alias Nasty.Data.OntoNotes
  alias Nasty.Semantic.Coreference.{Evaluator, Neural}
  alias Nasty.Semantic.Coreference.Neural.{E2EResolver, E2ETrainer}

  require Logger

  @impl Mix.Task
  def run(args) do
    # Start application
    Mix.Task.run("app.start")

    # Parse arguments
    opts = parse_args(args)

    # Validate
    case validate_opts(opts) do
      :ok ->
        evaluate(opts)

      {:error, message} ->
        Mix.shell().error(message)
        System.halt(1)
    end
  end

  defp evaluate(opts) do
    Logger.info("Loading test data from #{opts.test}...")

    # Load test data
    {:ok, test_docs} = OntoNotes.load_documents(opts.test)
    Logger.info("Loaded #{length(test_docs)} test documents")

    # Load neural models
    Logger.info("Loading e2e models from #{opts.model}...")

    case E2ETrainer.load_models(opts.model) do
      {:ok, models, params, vocab} ->
        Logger.info("Models loaded successfully")

        # Evaluate each document
        results =
          Enum.map(test_docs, fn doc ->
            gold_chains = doc.chains

            # Create document structure for resolution
            test_document = create_test_document(doc)

            # Resolve with e2e models
            {:ok, resolved} =
              E2EResolver.resolve(
                test_document,
                models,
                params,
                vocab,
                max_span_length: opts.max_span_length,
                top_k_spans: opts.top_k_spans,
                min_span_score: opts.min_span_score,
                min_coref_score: opts.min_coref_score
              )

            predicted_chains = resolved.coref_chains

            # Evaluate
            Evaluator.evaluate(gold_chains, predicted_chains)
          end)

        # Average results
        avg_metrics = average_metrics(results)

        # Print results
        Mix.shell().info("\nEnd-to-End Coreference Evaluation Results")
        Mix.shell().info("=========================================\n")
        Mix.shell().info(Evaluator.format_results(avg_metrics))

        if opts.baseline do
          # Compare with Phase 1 baseline
          Mix.shell().info("\nComparing with Phase 1 baseline...")
          baseline_results = evaluate_baseline(test_docs, opts)
          baseline_metrics = average_metrics(baseline_results)

          Mix.shell().info("\nPhase 1 Baseline Results")
          Mix.shell().info("========================\n")
          Mix.shell().info(Evaluator.format_results(baseline_metrics))

          # Show improvement
          improvement = avg_metrics.conll_f1 - baseline_metrics.conll_f1

          Mix.shell().info(
            "\nImprovement: #{if improvement >= 0, do: "+", else: ""}#{Float.round(improvement, 2)} F1 points"
          )
        end

      {:error, reason} ->
        Logger.error("Failed to load models: #{inspect(reason)}")
        System.halt(1)
    end
  end

  # Create a test document structure from OntoNotes doc
  defp create_test_document(_doc) do
    # Placeholder - would need to convert OntoNotes format to Nasty Document AST
    %Nasty.AST.Document{
      paragraphs: [],
      language: :en,
      coref_chains: [],
      span: {0, 0, 0, 0}
    }
  end

  # Evaluate with Phase 1 baseline (for comparison)
  defp evaluate_baseline(test_docs, opts) do
    # Load Phase 1 models if available
    baseline_path = Path.join(Path.dirname(opts.model), "coref")

    case Neural.Trainer.load_models(baseline_path) do
      {:ok, models, params, vocab} ->
        Enum.map(test_docs, fn doc ->
          gold_chains = doc.chains
          test_document = create_test_document(doc)

          {:ok, resolved} = Neural.Resolver.resolve(test_document, models, params, vocab)
          predicted_chains = resolved.coref_chains

          Evaluator.evaluate(gold_chains, predicted_chains)
        end)

      {:error, _} ->
        Logger.warning("Phase 1 baseline models not found, skipping comparison")
        []
    end
  end

  # Average metrics across documents
  defp average_metrics(results) do
    if Enum.empty?(results) do
      %{
        muc: %{precision: 0.0, recall: 0.0, f1: 0.0},
        b3: %{precision: 0.0, recall: 0.0, f1: 0.0},
        ceaf: %{precision: 0.0, recall: 0.0, f1: 0.0},
        conll_f1: 0.0
      }
    else
      n = length(results)

      avg_muc = average_metric(Enum.map(results, & &1.muc), n)
      avg_b3 = average_metric(Enum.map(results, & &1.b3), n)
      avg_ceaf = average_metric(Enum.map(results, & &1.ceaf), n)

      %{
        muc: avg_muc,
        b3: avg_b3,
        ceaf: avg_ceaf,
        conll_f1: (avg_muc.f1 + avg_b3.f1 + avg_ceaf.f1) / 3.0
      }
    end
  end

  defp average_metric(metrics, n) do
    %{
      precision: Enum.sum(Enum.map(metrics, & &1.precision)) / n,
      recall: Enum.sum(Enum.map(metrics, & &1.recall)) / n,
      f1: Enum.sum(Enum.map(metrics, & &1.f1)) / n
    }
  end

  defp parse_args(args) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          model: :string,
          test: :string,
          baseline: :boolean,
          max_span_length: :integer,
          top_k_spans: :integer,
          min_span_score: :float,
          min_coref_score: :float
        ]
      )

    %{
      model: parsed[:model],
      test: parsed[:test],
      baseline: parsed[:baseline] || false,
      max_span_length: parsed[:max_span_length] || 10,
      top_k_spans: parsed[:top_k_spans] || 50,
      min_span_score: parsed[:min_span_score] || 0.5,
      min_coref_score: parsed[:min_coref_score] || 0.5
    }
  end

  defp validate_opts(opts) do
    cond do
      is_nil(opts.model) ->
        {:error, "Missing required --model argument"}

      is_nil(opts.test) ->
        {:error, "Missing required --test argument"}

      !File.dir?(opts.test) ->
        {:error, "Test directory does not exist: #{opts.test}"}

      true ->
        :ok
    end
  end
end
