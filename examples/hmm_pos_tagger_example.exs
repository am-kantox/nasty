#!/usr/bin/env elixir

# Example: Training and using an HMM POS tagger
# 
# This script demonstrates:
# 1. Creating training data
# 2. Training an HMM model
# 3. Making predictions
# 4. Evaluating accuracy

alias Nasty.Statistics.POSTagging.HMMTagger
alias Nasty.Statistics.Evaluator

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
  {["A", "young", "dog", "ran", "quickly"], [:det, :adj, :noun, :verb, :adv]}
]

IO.puts("Training HMM POS Tagger...")
IO.puts("Training examples: #{length(training_data)}")

# Create and train model
model = HMMTagger.new(smoothing_k: 0.01)
{:ok, trained_model} = HMMTagger.train(model, training_data, [])

# Get model metadata
metadata = HMMTagger.metadata(trained_model)
IO.puts("\nModel trained successfully!")
IO.puts("  Tags: #{metadata.num_tags}")
IO.puts("  Vocabulary: #{metadata.vocab_size}")
IO.puts("  Training size: #{metadata.training_size}")

# Test predictions
test_sentences = [
  ["The", "cat", "ran"],
  ["A", "big", "bird", "flew"],
  ["The", "happy", "dog", "barked"]
]

IO.puts("\n--- Predictions ---")

Enum.each(test_sentences, fn words ->
  {:ok, predicted_tags} = HMMTagger.predict(trained_model, words, [])
  
  IO.puts("\nSentence: #{Enum.join(words, " ")}")
  IO.puts("Tags:     #{inspect(predicted_tags)}")
end)

# Evaluate on training data (for demonstration)
IO.puts("\n--- Evaluation on Training Data ---")

predictions =
  Enum.map(training_data, fn {words, gold_tags} ->
    {:ok, pred_tags} = HMMTagger.predict(trained_model, words, [])
    {gold_tags, pred_tags}
  end)

gold = predictions |> Enum.flat_map(&elem(&1, 0))
pred = predictions |> Enum.flat_map(&elem(&1, 1))

metrics = Evaluator.classification_metrics(gold, pred)

IO.puts("Accuracy: #{Float.round(metrics.accuracy * 100, 1)}%")
IO.puts("F1 Score: #{Float.round(metrics.f1, 3)}")

# Show some per-tag metrics
IO.puts("\nPer-tag metrics:")

[:det, :noun, :verb, :adj]
|> Enum.each(fn tag ->
  if Map.has_key?(metrics.per_class, tag) do
    class_metrics = metrics.per_class[tag]

    IO.puts(
      "  #{tag}: P=#{Float.round(class_metrics.precision, 3)} R=#{Float.round(class_metrics.recall, 3)} F1=#{Float.round(class_metrics.f1, 3)}"
    )
  end
end)

IO.puts("\n✓ Example complete!")
IO.puts(
  "\nNote: This is a toy example with minimal training data."
)

IO.puts("For real applications:")
IO.puts("  1. Download Universal Dependencies corpus (en_ewt-ud-*.conllu)")
IO.puts("  2. Use Nasty.Data.Corpus.load_ud/1 to load the data")
IO.puts("  3. Train on 10k+ sentences for production accuracy")
IO.puts("  4. Expect ~95% accuracy on standard benchmarks")
