defmodule Mix.Tasks.Nasty.Train.Coref do
  @moduledoc """
  Train neural coreference resolution models.

  ## Usage

      mix nasty.train.coref \\
        --corpus data/ontonotes/train \\
        --dev data/ontonotes/dev \\
        --output priv/models/en/coref \\
        --epochs 20 \\
        --batch-size 32 \\
        --learning-rate 0.001

  ## Options

    * `--corpus` - Path to training data directory (required)
    * `--dev` - Path to development data directory (required)
    * `--output` - Base path for saving models (required)
    * `--epochs` - Number of training epochs (default: 20)
    * `--batch-size` - Training batch size (default: 32)
    * `--learning-rate` - Learning rate (default: 0.001)
    * `--hidden-dim` - LSTM hidden dimension (default: 128)
    * `--dropout` - Dropout rate (default: 0.3)
    * `--patience` - Early stopping patience (default: 3)
    * `--max-distance` - Max sentence distance for pairs (default: 3)
  """

  @shortdoc "Train neural coreference models"

  use Mix.Task

  alias Nasty.Data.OntoNotes
  alias Nasty.Semantic.Coreference.Neural.{MentionEncoder, Trainer}

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
    train_data = OntoNotes.create_training_data(train_docs, max_distance: opts.max_distance)

    Logger.info("Loaded #{length(train_data)} training pairs")

    # Load dev data
    Logger.info("Loading dev data from #{opts.dev}...")
    {:ok, dev_docs} = OntoNotes.load_documents(opts.dev)
    dev_data = OntoNotes.create_training_data(dev_docs, max_distance: opts.max_distance)

    Logger.info("Loaded #{length(dev_data)} dev pairs")

    # Build vocabulary
    Logger.info("Building vocabulary...")
    vocab = MentionEncoder.build_vocab(train_docs ++ dev_docs)
    Logger.info("Vocabulary size: #{map_size(vocab)}")

    # Train models
    Logger.info("Training neural coreference models...")

    case Trainer.train(train_data, dev_data, vocab, opts) do
      {:ok, models, params, history} ->
        Logger.info("Training complete!")
        Logger.info("Best epoch: #{history.best_epoch}")
        Logger.info("Best dev loss: #{Float.round(Enum.min(history.dev_loss), 4)}")

        # Save models
        Logger.info("Saving models to #{opts.output}...")
        Trainer.save_models(models, params, vocab, opts.output)

        Logger.info("Models saved successfully!")

      {:error, reason} ->
        Logger.error("Training failed: #{inspect(reason)}")
        System.halt(1)
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
          max_distance: :integer
        ]
      )

    %{
      corpus: parsed[:corpus],
      dev: parsed[:dev],
      output: parsed[:output],
      epochs: parsed[:epochs] || 20,
      batch_size: parsed[:batch_size] || 32,
      learning_rate: parsed[:learning_rate] || 0.001,
      hidden_dim: parsed[:hidden_dim] || 128,
      dropout: parsed[:dropout] || 0.3,
      patience: parsed[:patience] || 3,
      max_distance: parsed[:max_distance] || 3
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
