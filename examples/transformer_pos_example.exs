# Transformer-based POS Tagging Example
#
# This example demonstrates how to use pre-trained transformer models
# (BERT, RoBERTa) for state-of-the-art POS tagging in Nasty.
#
# Requirements:
# - Internet connection (first run downloads models from HuggingFace)
# - ~500MB disk space for model cache
# - EXLA/CUDA optional for GPU acceleration
#
# Run with: mix run examples/transformer_pos_example.exs

alias Nasty.Language.English.{Tokenizer, POSTagger}
alias Nasty.Statistics.Neural.Transformers.{Loader, TokenClassifier, Inference}

IO.puts("\n=== Transformer-based POS Tagging Example ===\n")

# Sample texts to analyze
texts = [
  "The quick brown fox jumps over the lazy dog.",
  "Natural language processing transforms how we interact with computers.",
  "Machine learning models can achieve remarkable accuracy on linguistic tasks."
]

## Example 1: Basic Transformer POS Tagging
IO.puts("1. Basic Transformer POS Tagging with RoBERTa")
IO.puts(String.duplicate("-", 50))

text = hd(texts)
IO.puts("Text: #{text}\n")

# Tokenize the text
{:ok, tokens} = Tokenizer.tokenize(text)

# Tag with transformer model (RoBERTa-base)
# This will download the model on first run
IO.puts("Loading RoBERTa model (may take a few minutes on first run)...")
{:ok, tagged} = POSTagger.tag_pos(tokens, model: :roberta_base)

# Display results
IO.puts("\nPOS Tags:")
Enum.each(tagged, fn token ->
  IO.puts("  #{String.pad_trailing(token.text, 15)} -> #{token.pos_tag}")
end)

## Example 2: Comparing Model Accuracy
IO.puts("\n\n2. Comparing Different POS Tagging Models")
IO.puts(String.duplicate("-", 50))

IO.puts("Text: #{text}\n")

models_to_test = [
  {:rule_based, "Rule-based"},
  {:hmm, "HMM Statistical"},
  {:neural, "BiLSTM-CRF"},
  {:transformer, "Transformer (RoBERTa)"}
]

Enum.each(models_to_test, fn {model_type, description} ->
  IO.puts("\n#{description}:")

  case POSTagger.tag_pos(tokens, model: model_type) do
    {:ok, tagged_tokens} ->
      # Show first 5 tokens
      tagged_tokens
      |> Enum.take(5)
      |> Enum.each(fn t ->
        IO.puts("  #{String.pad_trailing(t.text, 12)} -> #{t.pos_tag}")
      end)

    {:error, reason} ->
      IO.puts("  Error: #{inspect(reason)}")
  end
end)

## Example 3: Manual Transformer Model Loading
IO.puts("\n\n3. Manual Transformer Model Configuration")
IO.puts(String.duplicate("-", 50))

# Load a specific transformer model
IO.puts("Loading BERT-base-cased model...")

case Loader.load_model(:bert_base_cased, cache_dir: "priv/models/transformers") do
  {:ok, base_model} ->
    IO.puts("Model loaded successfully!")
    IO.puts("  Model: #{base_model.name}")
    IO.puts("  Hidden size: #{base_model.config.hidden_size}")
    IO.puts("  Layers: #{base_model.config.num_layers}")
    IO.puts("  Parameters: ~#{div(base_model.config.params, 1_000_000)}M")

    # Create a POS classifier
    {:ok, classifier} =
      TokenClassifier.create(base_model,
        task: :pos_tagging,
        num_labels: 17,
        label_map: %{
          0 => "NOUN",
          1 => "VERB",
          2 => "ADJ",
          3 => "ADV",
          4 => "DET",
          5 => "ADP",
          6 => "PRON",
          7 => "CONJ",
          8 => "NUM",
          9 => "PART",
          10 => "PUNCT",
          11 => "X",
          12 => "AUX",
          13 => "PROPN",
          14 => "INTJ",
          15 => "SCONJ",
          16 => "SYM"
        }
      )

    IO.puts("  Classifier created with #{classifier.config.num_labels} labels")

    # Predict on tokens
    case TokenClassifier.predict(classifier, tokens) do
      {:ok, predictions} ->
        IO.puts("\nPredictions:")

        predictions
        |> Enum.zip(tokens)
        |> Enum.take(5)
        |> Enum.each(fn {pred, token} ->
          IO.puts(
            "  #{String.pad_trailing(token.text, 12)} -> #{pred.label} (#{Float.round(pred.score, 3)})"
          )
        end)

      {:error, reason} ->
        IO.puts("Prediction failed: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("Failed to load model: #{inspect(reason)}")
end

## Example 4: Optimized Inference with Caching
IO.puts("\n\n4. Optimized Inference with Caching and Compilation")
IO.puts(String.duplicate("-", 50))

case Loader.load_model(:roberta_base) do
  {:ok, base_model} ->
    {:ok, classifier} =
      TokenClassifier.create(base_model,
        task: :pos_tagging,
        num_labels: 17,
        label_map: %{0 => "NOUN", 1 => "VERB"}
      )

    # Optimize for inference
    IO.puts("Optimizing model for inference...")

    {:ok, optimized} =
      Inference.optimize_for_inference(classifier,
        optimizations: [:cache],
        cache_size: 1000,
        device: :cpu
      )

    IO.puts("Model optimized with caching enabled")

    # Process multiple texts efficiently
    IO.puts("\nProcessing #{length(texts)} texts with caching...\n")

    all_tokens =
      Enum.map(texts, fn text ->
        {:ok, tokens} = Tokenizer.tokenize(text)
        tokens
      end)

    case Inference.batch_predict(optimized, all_tokens) do
      {:ok, all_predictions} ->
        Enum.zip(texts, all_predictions)
        |> Enum.with_index(1)
        |> Enum.each(fn {{text, predictions}, idx} ->
          IO.puts("Text #{idx}: #{String.slice(text, 0..50)}...")
          IO.puts("  Predicted #{length(predictions)} POS tags")
        end)

        # Show cache statistics
        case Inference.cache_stats(optimized) do
          {:ok, stats} ->
            IO.puts("\nCache Statistics:")
            IO.puts("  Entries: #{stats.entries}")
            IO.puts("  Memory: #{stats.memory_words} words")

          :no_cache ->
            IO.puts("\nNo cache available")
        end

      {:error, reason} ->
        IO.puts("Batch prediction failed: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("Failed to load model: #{inspect(reason)}")
end

## Example 5: Available Models
IO.puts("\n\n5. Available Transformer Models")
IO.puts(String.duplicate("-", 50))

IO.puts("Supported models:")

available_models = Loader.list_models()

Enum.each(available_models, fn model_name ->
  case Loader.get_model_info(model_name) do
    {:ok, info} ->
      IO.puts("\n  #{model_name}:")
      IO.puts("    Parameters: ~#{div(info.params, 1_000_000)}M")
      IO.puts("    Hidden size: #{info.hidden_size}")
      IO.puts("    Layers: #{info.num_layers}")
      IO.puts("    Languages: #{inspect(info.languages)}")

    {:error, _} ->
      :ok
  end
end)

IO.puts("\n\n=== Example Complete ===")
IO.puts("\nKey Takeaways:")
IO.puts("  - Transformer models provide 98-99% POS tagging accuracy")
IO.puts("  - RoBERTa-base is recommended for English")
IO.puts("  - XLM-RoBERTa supports multilingual texts")
IO.puts("  - Use caching and compilation for production workloads")
IO.puts("  - Models are automatically cached after first download")
IO.puts("\nFor production use:")
IO.puts("  - Consider fine-tuning on domain-specific data")
IO.puts("  - Use GPU acceleration for large-scale processing")
IO.puts("  - Monitor cache size to avoid disk space issues")
