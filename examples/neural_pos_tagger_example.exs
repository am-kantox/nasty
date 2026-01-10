#!/usr/bin/env elixir

# Neural POS Tagger Example
#
# This script demonstrates how to create, train, and use a neural POS tagger
# using the BiLSTM-CRF architecture.
#
# Usage:
#   elixir examples/neural_pos_tagger_example.exs

alias Nasty.Statistics.POSTagging.NeuralTagger

IO.puts("=== Neural POS Tagger Example ===\n")

# Create some simple training data
# Format: {[words], [pos_tags]}
training_data = [
  {["The", "cat", "sat"], [:det, :noun, :verb]},
  {["The", "dog", "ran"], [:det, :noun, :verb]},
  {["A", "bird", "flew"], [:det, :noun, :verb]},
  {["The", "quick", "cat", "jumped"], [:det, :adj, :noun, :verb]},
  {["A", "big", "dog", "barked"], [:det, :adj, :noun, :verb]},
  {["The", "small", "bird", "sang"], [:det, :adj, :noun, :verb]},
  {["The", "cat", "and", "dog", "played"], [:det, :noun, :cconj, :noun, :verb]},
  {["A", "happy", "bird", "chirped", "loudly"], [:det, :adj, :noun, :verb, :adv]},
  {["The", "old", "cat", "slept"], [:det, :adj, :noun, :verb]},
  {["A", "young", "dog", "ran", "quickly"], [:det, :adj, :noun, :verb, :adv]},
  {["The", "beautiful", "bird", "sang", "sweetly"], [:det, :adj, :noun, :verb, :adv]},
  {["A", "lazy", "cat", "yawned"], [:det, :adj, :noun, :verb]},
  {["The", "energetic", "dog", "jumped", "high"], [:det, :adj, :noun, :verb, :adv]},
  {["A", "colorful", "bird", "flew", "away"], [:det, :adj, :noun, :verb, :adv]},
  {["The", "hungry", "cat", "meowed"], [:det, :adj, :noun, :verb]}
]

IO.puts("Training neural POS tagger...")
IO.puts("Training examples: #{length(training_data)}")
IO.puts("")

# Note: This is a toy example with minimal data
# For real applications, you would:
# 1. Load a Universal Dependencies corpus (10k+ sentences)
# 2. Train for 10-20 epochs
# 3. Expect 97-98% accuracy

IO.puts("Creating untrained neural tagger...")

# Create neural tagger with architecture options
# Note: vocabulary will be built automatically from training data during train/3
tagger =
  NeuralTagger.new(
    # Start with empty vocab - will be built from training data
    vocab: %{word_to_id: %{}, id_to_word: %{}, frequencies: %{}, size: 0},
    tag_vocab: %{tag_to_id: %{}, id_to_tag: %{}, size: 0},
    embedding_dim: 32,
    # Small for demo
    hidden_size: 64,
    # Small for demo
    num_layers: 1,
    # Single layer for speed
    dropout: 0.1
  )

IO.puts("Tagger created.")
IO.puts("")

# Train the model
# Note: With such small data and simple architecture, this is just for demonstration
# Real training would use much more data and larger models
IO.puts("Training model...")
IO.puts("Note: This may take a moment as EXLA compiles the neural network...")
IO.puts("")

case NeuralTagger.train(tagger, training_data,
       epochs: 3,
       batch_size: 4,
       learning_rate: 0.01,
       validation_split: 0.2
     ) do
  {:ok, trained_tagger} ->
    IO.puts("\nTraining completed!")

    # Test predictions
    test_sentences = [
      ["The", "cat", "ran"],
      ["A", "big", "bird", "flew"],
      ["The", "happy", "dog", "barked"]
    ]

    IO.puts("\n--- Predictions ---\n")

    Enum.each(test_sentences, fn words ->
      case NeuralTagger.predict(trained_tagger, words, []) do
        {:ok, predicted_tags} ->
          IO.puts("Sentence: #{Enum.join(words, " ")}")
          IO.puts("Tags:     #{inspect(predicted_tags)}")
          IO.puts("")

        {:error, reason} ->
          IO.puts("Prediction failed: #{inspect(reason)}")
      end
    end)

    # Save the model (optional)
    model_path = "/tmp/nasty_neural_pos_demo.axon"
    IO.puts("Saving model to #{model_path}...")

    case NeuralTagger.save(trained_tagger, model_path) do
      :ok ->
        IO.puts("Model saved successfully!")

        # Load it back
        IO.puts("Loading model back...")

        case NeuralTagger.load(model_path) do
          {:ok, loaded_tagger} ->
            IO.puts("Model loaded successfully!")

            # Test loaded model
            {:ok, tags} = NeuralTagger.predict(loaded_tagger, ["The", "cat", "sat"], [])
            IO.puts("\nLoaded model prediction: #{inspect(tags)}")

          {:error, reason} ->
            IO.puts("Failed to load model: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("Failed to save model: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("Training failed: #{inspect(reason)}")
end

IO.puts("\n=== Example Complete ===")
IO.puts("\nNote: This is a toy example with minimal training data.")
IO.puts("For real applications:")
IO.puts("  1. Use Universal Dependencies corpus (10k+ sentences)")
IO.puts("  2. Train with larger architecture (256-512 hidden units, 2 layers)")
IO.puts("  3. Train for 10-20 epochs")
IO.puts("  4. Expect 97-98% accuracy on standard benchmarks")
