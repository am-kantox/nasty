#!/usr/bin/env elixir

# Pretrained Model Usage Example
#
# This script demonstrates how to use a pre-trained statistical model
# for part-of-speech tagging.
#
# Prerequisites:
# - A trained model in priv/models/en/ (or specify path)
# - Run: mix nasty.train.pos --corpus PATH to create one
#
# Usage:
#   elixir examples/pretrained_model_usage.exs

# Parse text with automatic model loading
text = "The quick brown fox jumps over the lazy dog."

IO.puts("=== Pretrained Model Usage Example ===\n")
IO.puts("Text: #{text}\n")

# Example 1: Using HMM model (auto-loads from registry)
IO.puts("Example 1: HMM Model (auto-load)")
IO.puts("---")

case Nasty.parse(text, language: :en, model: :hmm) do
  {:ok, ast} ->
    # Extract tokens
    tokens =
      case ast do
        %Nasty.AST.Document{paragraphs: [%{sentences: [%{clauses: [clause]} | _]} | _]} ->
          extract_tokens_from_clause(clause)

        _ ->
          []
      end

    Enum.each(tokens, fn token ->
      IO.puts("  #{token.text} -> #{token.pos_tag}")
    end)

  {:error, reason} ->
    IO.puts("  Error: #{inspect(reason)}")
    IO.puts("  Note: Train a model first using: mix nasty.train.pos --corpus PATH")
end

IO.puts("")

# Example 2: Ensemble mode (HMM + rule-based fallback)
IO.puts("Example 2: Ensemble Mode")
IO.puts("---")

case Nasty.parse(text, language: :en, model: :ensemble) do
  {:ok, ast} ->
    tokens =
      case ast do
        %Nasty.AST.Document{paragraphs: [%{sentences: [%{clauses: [clause]} | _]} | _]} ->
          extract_tokens_from_clause(clause)

        _ ->
          []
      end

    Enum.each(tokens, fn token ->
      IO.puts("  #{token.text} -> #{token.pos_tag}")
    end)

  {:error, reason} ->
    IO.puts("  Error: #{inspect(reason)}")
end

IO.puts("")

# Example 3: Explicit model loading
IO.puts("Example 3: Explicit Model Loading")
IO.puts("---")

alias Nasty.Statistics.ModelLoader

case ModelLoader.load_latest(:en, :pos_tagging) do
  {:ok, model} ->
    IO.puts("  Model loaded successfully")
    metadata = Nasty.Statistics.POSTagging.HMMTagger.metadata(model)
    IO.puts("  Vocabulary size: #{metadata.vocab_size}")
    IO.puts("  Number of POS tags: #{metadata.num_tags}")
    IO.puts("  Training size: #{metadata.training_size}")

  {:error, :not_found} ->
    IO.puts("  No model found")
    IO.puts("  Train one using: mix nasty.train.pos --corpus PATH")
end

IO.puts("")

# Example 4: Model registry inspection
IO.puts("Example 4: Model Registry")
IO.puts("---")

models = Nasty.Statistics.ModelRegistry.list()

if Enum.empty?(models) do
  IO.puts("  No models in registry")
else
  Enum.each(models, fn {lang, task, version, metadata} ->
    IO.puts("  #{lang}-#{task}-#{version}")

    if Map.has_key?(metadata, :test_accuracy) do
      IO.puts("    Accuracy: #{Float.round(metadata.test_accuracy * 100, 2)}%")
    end
  end)
end

IO.puts("\n=== Example Complete ===")

# Helper function to extract tokens from a clause
defp extract_tokens_from_clause(clause) do
  # Extract from subject
  subject_tokens =
    case clause do
      %{subject: %Nasty.AST.NounPhrase{tokens: tokens}} -> tokens
      _ -> []
    end

  # Extract from predicate
  predicate_tokens =
    case clause do
      %{predicate: %Nasty.AST.VerbPhrase{verb: verb}} ->
        [verb] ++
          case clause.predicate do
            %{complements: comps} when is_list(comps) ->
              Enum.flat_map(comps, fn
                %Nasty.AST.NounPhrase{tokens: tokens} -> tokens
                %Nasty.AST.PrepositionalPhrase{tokens: tokens} -> tokens
                _ -> []
              end)

            _ ->
              []
          end

      _ ->
        []
    end

  subject_tokens ++ predicate_tokens
end
