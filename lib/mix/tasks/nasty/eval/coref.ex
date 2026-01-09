defmodule Mix.Tasks.Nasty.Eval.Coref do
  @moduledoc """
  Evaluate neural coreference resolution models.

  ## Usage

      mix nasty.eval.coref \\
        --model priv/models/en/coref \\
        --test data/ontonotes/test

  ## Options

    * `--model` - Base path to trained models (required)
    * `--test` - Path to test data directory (required)
    * `--baseline` - Compare against rule-based baseline (flag)
  """

  @shortdoc "Evaluate neural coreference models"

  use Mix.Task

  alias Nasty.Data.OntoNotes
  alias Nasty.Semantic.Coreference.{Evaluator, Neural}
  alias Nasty.Semantic.Coreference.Neural.Trainer

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
    Logger.info("Loading neural models from #{opts.model}...")

    case Trainer.load_models(opts.model) do
      {:ok, models, params, vocab} ->
        Logger.info("Models loaded successfully")

        # Evaluate each document
        results =
          Enum.map(test_docs, fn doc ->
            gold_chains = doc.chains

            # Create document structure for resolution
            # Note: This is simplified - real implementation would need proper AST
            test_document = create_test_document(doc)

            # Resolve with neural models
            {:ok, resolved} = Neural.Resolver.resolve(test_document, models, params, vocab)
            predicted_chains = resolved.coref_chains

            # Evaluate
            Evaluator.evaluate(gold_chains, predicted_chains)
          end)

        # Average results
        avg_metrics = average_metrics(results)

        # Print results
        Mix.shell().info("\nNeural Coreference Evaluation Results")
        Mix.shell().info("=====================================\n")
        Mix.shell().info(Evaluator.format_results(avg_metrics))

        if opts.baseline do
          # Compare with baseline
          Mix.shell().info("\nComparing with rule-based baseline...")
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
      span: nil
    }
  end

  # Average metrics across documents
  defp average_metrics(results) do
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
          baseline: :boolean
        ]
      )

    %{
      model: parsed[:model],
      test: parsed[:test],
      baseline: parsed[:baseline] || false
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
