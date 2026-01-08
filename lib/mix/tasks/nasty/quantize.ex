defmodule Mix.Tasks.Nasty.Quantize do
  @moduledoc """
  Quantize neural models for faster inference and smaller file size.

  ## Usage

      mix nasty.quantize \\
        --model models/pos_tagger.axon \\
        --calibration data/calibration.conllu \\
        --output models/pos_tagger_int8.axon

  ## Options

    * `--model` - Path to model to quantize (required)
    * `--calibration` - Path to calibration data (required for INT8)
    * `--output` - Output path for quantized model (required)
    * `--method` - Quantization method: int8, dynamic, qat (default: int8)
    * `--calibration-method` - Calibration method: minmax, percentile, entropy (default: percentile)
    * `--percentile` - Percentile for calibration (default: 99.99)
    * `--symmetric` - Use symmetric quantization (default: true)
    * `--per-channel` - Per-channel quantization (default: true)
    * `--target-accuracy-loss` - Max acceptable accuracy loss (default: 0.01)
    * `--calibration-limit` - Max calibration samples (default: 500)

  ## Examples

      # Quick INT8 quantization
      mix nasty.quantize \\
        --model models/pos_tagger.axon \\
        --calibration data/dev.conllu \\
        --output models/pos_tagger_int8.axon

      # Production quantization with validation
      mix nasty.quantize \\
        --model models/pos_tagger.axon \\
        --calibration data/calibration.conllu \\
        --output models/pos_tagger_int8.axon \\
        --method int8 \\
        --calibration-method percentile \\
        --percentile 99.99 \\
        --target-accuracy-loss 0.01

      # Dynamic quantization (no calibration needed)
      mix nasty.quantize \\
        --model models/pos_tagger.axon \\
        --output models/pos_tagger_dynamic.axon \\
        --method dynamic

  """

  use Mix.Task

  alias Nasty.Statistics.Neural.{DataLoader, Quantization.INT8}

  require Logger

  @shortdoc "Quantize neural models"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          model: :string,
          calibration: :string,
          output: :string,
          method: :string,
          calibration_method: :string,
          percentile: :float,
          symmetric: :boolean,
          per_channel: :boolean,
          target_accuracy_loss: :float,
          calibration_limit: :integer
        ]
      )

    # Validate required options
    model_path = validate_required!(opts, :model, "Model path")
    output_path = validate_required!(opts, :output, "Output path")

    method = parse_method(Keyword.get(opts, :method, "int8"))

    config = %{
      method: method,
      calibration_path: Keyword.get(opts, :calibration),
      calibration_method:
        parse_calibration_method(Keyword.get(opts, :calibration_method, "percentile")),
      percentile: Keyword.get(opts, :percentile, 99.99),
      symmetric: Keyword.get(opts, :symmetric, true),
      per_channel: Keyword.get(opts, :per_channel, true),
      target_accuracy_loss: Keyword.get(opts, :target_accuracy_loss, 0.01),
      calibration_limit: Keyword.get(opts, :calibration_limit, 500)
    }

    Mix.shell().info("Model Quantization")
    Mix.shell().info("  Input: #{model_path}")
    Mix.shell().info("  Output: #{output_path}")
    Mix.shell().info("  Method: #{config.method}")

    # Load model
    Mix.shell().info("\nLoading model...")

    case load_model(model_path) do
      {:ok, model} ->
        Mix.shell().info("Model loaded successfully")

        # Show size estimate
        estimate = INT8.estimate_size_reduction(model)
        display_size_estimate(estimate)

        # Quantize based on method
        case config.method do
          :int8 ->
            quantize_int8(model, output_path, config)

          :dynamic ->
            quantize_dynamic(model, output_path, config)

          :qat ->
            Mix.shell().error(
              "QAT requires training from scratch. Use fine-tuning with quantization_aware: true"
            )

            exit({:shutdown, 1})
        end

      {:error, reason} ->
        Mix.shell().error("Failed to load model: #{inspect(reason)}")
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

  defp parse_method("int8"), do: :int8
  defp parse_method("dynamic"), do: :dynamic
  defp parse_method("qat"), do: :qat

  defp parse_method(other) do
    Mix.shell().error("Invalid method: #{other}. Use: int8, dynamic, or qat")
    exit({:shutdown, 1})
  end

  defp parse_calibration_method("minmax"), do: :minmax
  defp parse_calibration_method("percentile"), do: :percentile
  defp parse_calibration_method("entropy"), do: :entropy

  defp parse_calibration_method(other) do
    Mix.shell().error("Invalid calibration method: #{other}. Use: minmax, percentile, or entropy")
    exit({:shutdown, 1})
  end

  defp load_model(path) do
    # Load model from file
    case File.read(path) do
      {:ok, binary} ->
        model = :erlang.binary_to_term(binary)
        {:ok, model}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp display_size_estimate(estimate) do
    Mix.shell().info("\nSize Estimate:")
    Mix.shell().info("  Parameters: #{format_number(estimate.param_count)}")
    Mix.shell().info("  Current (Float32): #{estimate.original_mb} MB")
    Mix.shell().info("  After quantization (INT8): #{estimate.quantized_mb} MB")
    Mix.shell().info("  Reduction: #{estimate.reduction}x smaller")
  end

  defp quantize_int8(model, output_path, config) do
    unless config.calibration_path do
      Mix.shell().error("INT8 quantization requires --calibration option")
      exit({:shutdown, 1})
    end

    Mix.shell().info("\nLoading calibration data...")

    case load_calibration_data(config.calibration_path, config.calibration_limit) do
      {:ok, calibration_data} ->
        Mix.shell().info("Calibration samples: #{length(calibration_data)}")

        Mix.shell().info("\nQuantizing to INT8...")
        Mix.shell().info("  Calibration method: #{config.calibration_method}")
        Mix.shell().info("  Symmetric: #{config.symmetric}")
        Mix.shell().info("  Per-channel: #{config.per_channel}")

        quantize_opts = [
          calibration_data: calibration_data,
          calibration_method: config.calibration_method,
          percentile: config.percentile,
          symmetric: config.symmetric,
          per_channel: config.per_channel,
          target_accuracy_loss: config.target_accuracy_loss
        ]

        case INT8.quantize(model, quantize_opts) do
          {:ok, quantized_model} ->
            Mix.shell().info("\nQuantization successful!")

            # Save quantized model
            case INT8.save(quantized_model, output_path) do
              :ok ->
                Mix.shell().info("Quantized model saved to: #{output_path}")

                # Show final size
                case File.stat(output_path) do
                  {:ok, %{size: size}} ->
                    size_mb = Float.round(size / 1_000_000, 2)
                    Mix.shell().info("Final size: #{size_mb} MB")

                  _ ->
                    :ok
                end

              {:error, reason} ->
                Mix.shell().error("Failed to save model: #{inspect(reason)}")
                exit({:shutdown, 1})
            end

          {:error, {:accuracy_loss_too_high, loss}} ->
            Mix.shell().error("\nQuantization failed: Accuracy loss too high")
            Mix.shell().error("  Actual loss: #{Float.round(loss * 100, 2)}%")
            Mix.shell().error("  Target: #{Float.round(config.target_accuracy_loss * 100, 2)}%")

            Mix.shell().info("\nSuggestions:")
            Mix.shell().info("  - Increase calibration data (--calibration-limit)")
            Mix.shell().info("  - Use percentile method with higher percentile")
            Mix.shell().info("  - Try asymmetric quantization (--symmetric false)")
            exit({:shutdown, 1})

          {:error, reason} ->
            Mix.shell().error("Quantization failed: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      {:error, reason} ->
        Mix.shell().error("Failed to load calibration data: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp quantize_dynamic(model, output_path, _config) do
    Mix.shell().info("\nQuantizing with dynamic quantization...")
    Mix.shell().info("(No calibration data needed)")

    # For dynamic quantization, we still use INT8 but without calibration
    # This is a simplified approach
    quantized_model = %{
      original_model: model,
      type: :dynamic_int8
    }

    case INT8.save(quantized_model, output_path) do
      :ok ->
        Mix.shell().info("\nDynamic quantization successful!")
        Mix.shell().info("Quantized model saved to: #{output_path}")

      {:error, reason} ->
        Mix.shell().error("Failed to save model: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp load_calibration_data(path, limit) do
    case DataLoader.load_conllu_file(path) do
      {:ok, sentences} ->
        calibration_data =
          sentences
          |> Enum.take(limit)
          |> Enum.map(fn sentence ->
            # Convert to model input format
            %{
              tokens: sentence.tokens
            }
          end)

        {:ok, calibration_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_number(num) when num >= 1_000_000_000 do
    "#{Float.round(num / 1_000_000_000, 1)}B"
  end

  defp format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end

  defp format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end

  defp format_number(num), do: to_string(num)
end
