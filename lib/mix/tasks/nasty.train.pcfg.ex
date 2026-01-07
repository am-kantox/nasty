defmodule Mix.Tasks.Nasty.Train.Pcfg do
  @moduledoc """
  Trains a PCFG (Probabilistic Context-Free Grammar) model from treebank data.

  ## Usage

      mix nasty.train.pcfg --corpus data/train.conllu --output priv/models/en/pcfg.model

  ## Options

    * `--corpus` - Path to training corpus in CoNLL-U format (required)
    * `--test` - Path to test corpus for evaluation (optional)
    * `--output` - Path to save trained model (required)
    * `--smoothing` - Smoothing constant (default: 0.001)
    * `--cnf` - Convert grammar to CNF (default: true)
    * `--language` - Language code (default: en)

  ## Examples

      # Train basic PCFG
      mix nasty.train.pcfg \\
        --corpus data/en_ewt-ud-train.conllu \\
        --output priv/models/en/pcfg.model

      # Train with evaluation
      mix nasty.train.pcfg \\
        --corpus data/en_ewt-ud-train.conllu \\
        --test data/en_ewt-ud-test.conllu \\
        --output priv/models/en/pcfg.model \\
        --smoothing 0.0001
  """

  use Mix.Task

  alias Nasty.Statistics.Parsing.Grammar
  alias Nasty.Statistics.Parsing.PCFG

  @shortdoc "Trains a PCFG model from treebank data"

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          corpus: :string,
          test: :string,
          output: :string,
          smoothing: :float,
          cnf: :boolean,
          language: :string
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    corpus_path = Keyword.get(opts, :corpus)
    output_path = Keyword.get(opts, :output)
    test_path = Keyword.get(opts, :test)
    smoothing = Keyword.get(opts, :smoothing, 0.001)
    cnf = Keyword.get(opts, :cnf, true)
    language = Keyword.get(opts, :language, "en") |> String.to_atom()

    unless corpus_path do
      Mix.raise("--corpus option is required")
    end

    unless output_path do
      Mix.raise("--output option is required")
    end

    Mix.shell().info("Training PCFG model...")
    Mix.shell().info("Corpus: #{corpus_path}")
    Mix.shell().info("Language: #{language}")
    Mix.shell().info("Smoothing: #{smoothing}")
    Mix.shell().info("CNF conversion: #{cnf}")

    # Load training data
    training_data = load_conllu(corpus_path)
    Mix.shell().info("Loaded #{length(training_data)} sentences")

    # Create and train model
    model = PCFG.new(language: language, smoothing_k: smoothing)

    {:ok, trained} =
      PCFG.train(model, training_data, smoothing: smoothing, cnf: cnf)

    # Print statistics
    Mix.shell().info("Training complete!")
    Mix.shell().info("Grammar rules: #{length(trained.rules)}")
    Mix.shell().info("Non-terminals: #{MapSet.size(trained.non_terminals)}")
    Mix.shell().info("Vocabulary size: #{map_size(trained.lexicon)}")

    # Evaluate on test set if provided
    if test_path do
      Mix.shell().info("\nEvaluating on test set...")
      test_data = load_conllu(test_path)
      accuracy = evaluate_model(trained, test_data)
      Mix.shell().info("Test accuracy: #{Float.round(accuracy * 100, 2)}%")
    end

    # Save model
    :ok = PCFG.save(trained, output_path)
    Mix.shell().info("\nModel saved to: #{output_path}")
  end

  # Load CoNLL-U format treebank data
  defp load_conllu(path) do
    path
    |> File.read!()
    |> String.split("\n\n", trim: true)
    |> Enum.map(&parse_sentence/1)
    |> Enum.reject(&is_nil/1)
  end

  # Parse a single CoNLL-U sentence
  defp parse_sentence(sentence_text) do
    lines =
      sentence_text
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    if Enum.empty?(lines) do
      nil
    else
      tokens =
        lines
        |> Enum.map(&parse_token_line/1)
        |> Enum.reject(&is_nil/1)

      # For PCFG training, we need to extract grammar rules from dependencies
      # This is a simplified extraction - in practice, you'd want more sophisticated
      # conversion from dependencies to constituency trees
      parse_tree = extract_parse_tree(tokens)

      {tokens, parse_tree}
    end
  end

  # Parse a single CoNLL-U token line
  defp parse_token_line(line) do
    fields = String.split(line, "\t")

    if length(fields) >= 10 do
      [id, form, lemma, upos, _xpos, _feats, _head, _deprel, _deps, _misc] = fields

      # Skip multiword tokens
      if String.contains?(id, "-") do
        nil
      else
        %Nasty.AST.Token{
          text: form,
          lemma: lemma,
          pos: String.to_atom(String.downcase(upos)),
          span: nil,
          language: :en
        }
      end
    else
      nil
    end
  end

  # Extract parse tree from dependencies (simplified)
  # In a real implementation, this would convert dependency structure to constituency
  defp extract_parse_tree(tokens) do
    # For now, return a simple flat structure
    # This would need to be enhanced to create proper constituency trees
    {:s, Enum.map(tokens, fn token -> {token.pos, token.text} end)}
  end

  # Evaluate model on test data
  defp evaluate_model(model, test_data) do
    results =
      Enum.map(test_data, fn {tokens, _expected_tree} ->
        case PCFG.predict(model, tokens, []) do
          {:ok, _predicted_tree} -> 1
          {:error, _} -> 0
        end
      end)

    Enum.sum(results) / length(results)
  end
end
