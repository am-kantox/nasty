defmodule Mix.Tasks.Nasty.FineTune.Pos do
  @moduledoc """
  Fine-tunes a pre-trained transformer model for POS tagging.

  ## Usage

      mix nasty.fine_tune.pos \\
        --model roberta_base \\
        --train data/en_ewt-ud-train.conllu \\
        --validation data/en_ewt-ud-dev.conllu \\
        --output models/pos_finetuned \\
        --epochs 3 \\
        --batch-size 16

  ## Options

    * `--model` - Base transformer model to fine-tune (required)
      Options: bert_base_cased, roberta_base, xlm_roberta_base
    * `--train` - Path to training data in CoNLL-U format (required)
    * `--validation` - Path to validation data (optional)
    * `--output` - Output directory for fine-tuned model (default: priv/models/finetuned)
    * `--epochs` - Number of training epochs (default: 3)
    * `--batch-size` - Training batch size (default: 16)
    * `--learning-rate` - Learning rate (default: 3e-5)
    * `--max-length` - Maximum sequence length (default: 512)
    * `--eval-steps` - Evaluate every N steps (default: 500)

  ## Examples

      # Quick fine-tuning with defaults
      mix nasty.fine_tune.pos --model roberta_base --train data/train.conllu

      # Full configuration
      mix nasty.fine_tune.pos \\
        --model bert_base_cased \\
        --train data/train.conllu \\
        --validation data/dev.conllu \\
        --epochs 5 \\
        --batch-size 32 \\
        --learning-rate 0.00002 \\
        --output models/pos_bert_finetuned

  """

  use Mix.Task

  alias Nasty.Statistics.Neural.DataLoader
  alias Nasty.Statistics.Neural.Transformers.{DataPreprocessor, FineTuner, Loader}

  require Logger

  @shortdoc "Fine-tune transformer for POS tagging"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          model: :string,
          train: :string,
          validation: :string,
          output: :string,
          epochs: :integer,
          batch_size: :integer,
          learning_rate: :float,
          max_length: :integer,
          eval_steps: :integer
        ]
      )

    # Validate required options
    model_name = validate_required!(opts, :model, "Base model name")
    train_path = validate_required!(opts, :train, "Training data path")

    # Parse options with defaults
    config = %{
      validation_path: Keyword.get(opts, :validation),
      output_dir: Keyword.get(opts, :output, "priv/models/finetuned"),
      epochs: Keyword.get(opts, :epochs, 3),
      batch_size: Keyword.get(opts, :batch_size, 16),
      learning_rate: Keyword.get(opts, :learning_rate, 3.0e-5),
      max_length: Keyword.get(opts, :max_length, 512),
      eval_steps: Keyword.get(opts, :eval_steps, 500),
      save_steps: Keyword.get(opts, :save_steps, 1000)
    }

    Mix.shell().info("Fine-tuning POS tagger")
    Mix.shell().info("  Model: #{model_name}")
    Mix.shell().info("  Training data: #{train_path}")
    Mix.shell().info("  Output: #{config.output_dir}")

    # Load base model
    Mix.shell().info("\nLoading base model...")

    case load_base_model(model_name) do
      {:ok, base_model} ->
        Mix.shell().info("Model loaded: #{base_model.name}")

        # Load training data
        Mix.shell().info("\nLoading training data...")

        case load_training_data(train_path, config.validation_path) do
          {:ok, train_data, valid_data} ->
            Mix.shell().info("Training examples: #{length(train_data)}")

            if valid_data do
              Mix.shell().info("Validation examples: #{length(valid_data)}")
            end

            # Extract labels and create label map
            # [TODO] `labels`
            _labels = DataPreprocessor.extract_labels(Enum.map(train_data, &elem(&1, 0)), :pos)
            label_map = create_upos_label_map()
            num_labels = map_size(label_map)

            Mix.shell().info("Number of POS tags: #{num_labels}")

            # Fine-tune
            Mix.shell().info("\nStarting fine-tuning...")

            fine_tune_opts = [
              num_labels: num_labels,
              label_map: label_map,
              validation_data: valid_data,
              epochs: config.epochs,
              batch_size: config.batch_size,
              learning_rate: config.learning_rate
            ]

            case FineTuner.fine_tune(base_model, train_data, :pos_tagging, fine_tune_opts) do
              {:ok, finetuned_model} ->
                Mix.shell().info("\nFine-tuning completed successfully!")
                Mix.shell().info("Model saved to: #{config.output_dir}")

                # Evaluate on validation set if available
                if valid_data do
                  Mix.shell().info("\nEvaluating on validation set...")

                  case FineTuner.evaluate(finetuned_model, valid_data) do
                    {:ok, metrics} ->
                      display_metrics(metrics)

                    {:error, reason} ->
                      Mix.shell().error("Evaluation failed: #{inspect(reason)}")
                  end
                end

              {:error, reason} ->
                Mix.shell().error("Fine-tuning failed: #{inspect(reason)}")
                exit({:shutdown, 1})
            end

          {:error, reason} ->
            Mix.shell().error("Failed to load training data: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      {:error, reason} ->
        Mix.shell().error("Failed to load base model: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp validate_required!(opts, key, description) do
    case Keyword.fetch(opts, key) do
      {:ok, value} ->
        value

      :error ->
        Mix.shell().error("Missing required option: --#{key} (#{description})")
        exit({:shutdown, 1})
    end
  end

  defp load_base_model(model_name) do
    model_atom = String.to_atom(model_name)
    Loader.load_model(model_atom)
  rescue
    ArgumentError ->
      {:error, :invalid_model_name}
  end

  defp load_training_data(train_path, validation_path) do
    with {:ok, train_sentences} <- DataLoader.load_conllu_file(train_path),
         train_data <- prepare_examples(train_sentences),
         valid_data <- load_validation_data(validation_path) do
      {:ok, train_data, valid_data}
    end
  end

  defp load_validation_data(nil), do: nil

  defp load_validation_data(path) do
    case DataLoader.load_conllu_file(path) do
      {:ok, sentences} -> prepare_examples(sentences)
      {:error, _} -> nil
    end
  end

  defp prepare_examples(sentences) do
    # Convert CoNLL-U sentences to {tokens, labels} format
    Enum.map(sentences, fn sentence ->
      tokens = sentence.tokens
      labels = Enum.map(tokens, & &1.pos)
      {tokens, labels}
    end)
  end

  defp create_upos_label_map do
    # Universal POS tags
    upos_tags = [
      :adj,
      :adp,
      :adv,
      :aux,
      :cconj,
      :det,
      :intj,
      :noun,
      :num,
      :part,
      :pron,
      :propn,
      :punct,
      :sconj,
      :sym,
      :verb,
      :x
    ]

    upos_tags
    |> Enum.with_index()
    |> Map.new(fn {tag, idx} -> {idx, Atom.to_string(tag) |> String.upcase()} end)
  end

  defp display_metrics(metrics) do
    Mix.shell().info("\nValidation Results:")
    Mix.shell().info("  Accuracy: #{Float.round(metrics.accuracy * 100, 2)}%")
    Mix.shell().info("  Total predictions: #{metrics.total_predictions}")
    Mix.shell().info("  Correct predictions: #{metrics.correct_predictions}")
  end
end
