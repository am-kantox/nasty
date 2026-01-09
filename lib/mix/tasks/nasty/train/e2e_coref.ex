defmodule Mix.Tasks.Nasty.Train.E2eCoref do
  @moduledoc """
  Train end-to-end span-based coreference resolution models.

  ## Usage

      mix nasty.train.e2e_coref \\
        --corpus data/ontonotes/train \\
        --dev data/ontonotes/dev \\
        --output priv/models/en/e2e_coref \\
        --epochs 25 \\
        --batch-size 16 \\
        --learning-rate 0.0005

  ## Options

    * `--corpus` - Path to training data directory (required)
    * `--dev` - Path to development data directory (required)
    * `--output` - Base path for saving models (required)
    * `--epochs` - Number of training epochs (default: 25)
    * `--batch-size` - Training batch size (default: 16)
    * `--learning-rate` - Learning rate (default: 0.0005)
    * `--hidden-dim` - LSTM hidden dimension (default: 256)
    * `--dropout` - Dropout rate (default: 0.3)
    * `--patience` - Early stopping patience (default: 3)
    * `--max-span-width` - Maximum span width (default: 10)
    * `--top-k-spans` - Keep top K spans per sentence (default: 50)
    * `--span-loss-weight` - Weight for span detection loss (default: 0.3)
    * `--coref-loss-weight` - Weight for coreference loss (default: 0.7)
  """

  @shortdoc "Train end-to-end coreference models"

  use Mix.Task

  alias Nasty.Data.OntoNotes
  alias Nasty.Semantic.Coreference.Neural.{E2ETrainer, MentionEncoder}

  require Logger

  @impl Mix.Task
  def run(args) do
    # Start application
    Mix.Task.run("app.start")

    # Parse arguments
    opts = parse_args(args)

    # Validate required arguments
    case validate_opts(opts) do
      :ok ->
        train(opts)

      {:error, message} ->
        Mix.shell().error(message)
        System.halt(1)
    end
  end

  defp train(opts) do
    Logger.info("Loading training data from #{opts.corpus}...")

    # Load training data
    {:ok, train_docs} = OntoNotes.load_documents(opts.corpus)

    # Create span training data
    train_data =
      OntoNotes.create_span_training_data(train_docs,
        max_span_width: opts.max_span_width,
        negative_span_ratio: 3.0
      )

    # Also create antecedent data for coreference
    antecedent_data =
      OntoNotes.create_antecedent_data(train_docs,
        max_antecedent_distance: 50,
        negative_antecedent_ratio: 1.5
      )

    # Combine both types of training data
    combined_data = train_data ++ antecedent_data

    Logger.info("Loaded #{length(combined_data)} training examples")

    # Load dev data
    Logger.info("Loading dev data from #{opts.dev}...")
    {:ok, dev_docs} = OntoNotes.load_documents(opts.dev)

    dev_data =
      OntoNotes.create_span_training_data(dev_docs,
        max_span_width: opts.max_span_width,
        negative_span_ratio: 3.0
      )

    Logger.info("Loaded #{length(dev_data)} dev examples")

    # Build vocabulary
    Logger.info("Building vocabulary...")
    vocab = MentionEncoder.build_vocab(train_docs ++ dev_docs)
    Logger.info("Vocabulary size: #{map_size(vocab)}")

    # Train models
    Logger.info("Training end-to-end coreference models...")

    case E2ETrainer.train(combined_data, dev_data, vocab, opts) do
      {:ok, models, params, history} ->
        Logger.info("Training complete!")
        Logger.info("Best epoch: #{history.best_epoch}")
        Logger.info("Best dev F1: #{Float.round(history.best_f1, 2)}")

        # Save models
        Logger.info("Saving models to #{opts.output}...")
        E2ETrainer.save_models(models, params, vocab, opts.output)

        Logger.info("Models saved successfully!")

        # [TODO] `E2ETrainer.train/4` should in future return errors too
        # {:error, reason} ->
        #   Logger.error("Training failed: #{inspect(reason)}")
        #   System.halt(1)
    end
  end

  defp parse_args(args) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          corpus: :string,
          dev: :string,
          output: :string,
          epochs: :integer,
          batch_size: :integer,
          learning_rate: :float,
          hidden_dim: :integer,
          dropout: :float,
          patience: :integer,
          max_span_width: :integer,
          top_k_spans: :integer,
          span_loss_weight: :float,
          coref_loss_weight: :float
        ]
      )

    %{
      corpus: parsed[:corpus],
      dev: parsed[:dev],
      output: parsed[:output],
      epochs: parsed[:epochs] || 25,
      batch_size: parsed[:batch_size] || 16,
      learning_rate: parsed[:learning_rate] || 0.0005,
      hidden_dim: parsed[:hidden_dim] || 256,
      dropout: parsed[:dropout] || 0.3,
      patience: parsed[:patience] || 3,
      max_span_width: parsed[:max_span_width] || 10,
      top_k_spans: parsed[:top_k_spans] || 50,
      span_loss_weight: parsed[:span_loss_weight] || 0.3,
      coref_loss_weight: parsed[:coref_loss_weight] || 0.7
    }
  end

  defp validate_opts(opts) do
    cond do
      is_nil(opts.corpus) ->
        {:error, "Missing required --corpus argument"}

      is_nil(opts.dev) ->
        {:error, "Missing required --dev argument"}

      is_nil(opts.output) ->
        {:error, "Missing required --output argument"}

      !File.dir?(opts.corpus) ->
        {:error, "Corpus directory does not exist: #{opts.corpus}"}

      !File.dir?(opts.dev) ->
        {:error, "Dev directory does not exist: #{opts.dev}"}

      true ->
        :ok
    end
  end
end
