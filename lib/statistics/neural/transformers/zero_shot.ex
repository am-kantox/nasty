defmodule Nasty.Statistics.Neural.Transformers.ZeroShot do
  @moduledoc """
  Zero-shot classification using pre-trained models.

  Allows classification of text into arbitrary categories without any
  task-specific training. Uses Natural Language Inference (NLI) models
  trained on MNLI to perform zero-shot classification.

  ## How it works

  The model treats classification as a textual entailment problem:
  - Hypothesis: "This text is about {label}"
  - Premise: The input text
  - The model predicts entailment probability for each label

  ## Supported Models

  Best models for zero-shot classification:
  - `:roberta_large_mnli` - RoBERTa fine-tuned on MNLI (best accuracy)
  - `:bart_large_mnli` - BART fine-tuned on MNLI
  - `:xlm_roberta_base` - Multilingual zero-shot (63 languages)

  ## Examples

      # Sentiment analysis
      {:ok, result} = ZeroShot.classify("I love this product!",
        candidate_labels: ["positive", "negative", "neutral"]
      )
      # => %{label: "positive", scores: %{"positive" => 0.95, ...}}

      # Topic classification
      {:ok, result} = ZeroShot.classify(article_text,
        candidate_labels: ["politics", "sports", "technology", "business"]
      )

      # Multi-label classification
      {:ok, results} = ZeroShot.classify(text,
        candidate_labels: ["urgent", "action_required", "informational"],
        multi_label: true
      )
  """

  alias Nasty.Statistics.Neural.Transformers.Loader

  require Logger

  @type classification_result :: %{
          label: String.t(),
          scores: %{String.t() => float()},
          sequence: String.t()
        }

  @type multi_label_result :: %{
          labels: [String.t()],
          scores: %{String.t() => float()},
          sequence: String.t()
        }

  @doc """
  Classifies text into one of the candidate labels using zero-shot learning.

  ## Options

    * `:candidate_labels` - List of possible labels (required)
    * `:model` - Model to use (default: :roberta_large_mnli)
    * `:multi_label` - Allow multiple labels (default: false)
    * `:hypothesis_template` - Template for hypothesis (default: "This text is about {}")
    * `:threshold` - Minimum score for multi-label (default: 0.5)

  ## Examples

      {:ok, result} = ZeroShot.classify("Python is a programming language",
        candidate_labels: ["technology", "biology", "geography"]
      )

      {:ok, result} = ZeroShot.classify(text,
        candidate_labels: ["urgent", "normal"],
        hypothesis_template: "This message is {}"
      )
  """
  @spec classify(String.t(), keyword()) ::
          {:ok, classification_result() | multi_label_result()} | {:error, term()}
  def classify(text, opts) do
    candidate_labels = Keyword.fetch!(opts, :candidate_labels)
    model_name = Keyword.get(opts, :model, :roberta_large_mnli)
    multi_label = Keyword.get(opts, :multi_label, false)
    hypothesis_template = Keyword.get(opts, :hypothesis_template, "This text is about {}")

    with :ok <- validate_inputs(text, candidate_labels),
         {:ok, model} <- load_nli_model(model_name, opts),
         {:ok, scores} <- score_labels(model, text, candidate_labels, hypothesis_template) do
      result =
        if multi_label do
          threshold = Keyword.get(opts, :threshold, 0.5)
          build_multi_label_result(text, scores, threshold)
        else
          build_single_label_result(text, scores)
        end

      {:ok, result}
    end
  end

  @doc """
  Classifies multiple texts in batch for efficiency.

  ## Examples

      texts = ["text1", "text2", "text3"]
      {:ok, results} = ZeroShot.classify_batch(texts,
        candidate_labels: ["positive", "negative"]
      )
  """
  @spec classify_batch([String.t()], keyword()) ::
          {:ok, [classification_result() | multi_label_result()]} | {:error, term()}
  def classify_batch(texts, opts) do
    # Process each text
    results =
      Enum.map(texts, fn text ->
        classify(text, opts)
      end)

    # Check if all succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      classifications = Enum.map(results, fn {:ok, result} -> result end)
      {:ok, classifications}
    else
      first_error = Enum.find(results, &match?({:error, _}, &1))
      first_error
    end
  end

  @doc """
  Gets recommended models for zero-shot classification.

  ## Examples

      ZeroShot.recommended_models()
      # => [:roberta_large_mnli, :bart_large_mnli, :xlm_roberta_base]
  """
  @spec recommended_models() :: [atom()]
  def recommended_models do
    [:roberta_large_mnli, :bart_large_mnli, :xlm_roberta_base]
  end

  # Private functions

  defp validate_inputs("", _), do: {:error, :empty_text}
  defp validate_inputs(_, []), do: {:error, :no_candidate_labels}
  defp validate_inputs(_, [_single]), do: {:error, :need_multiple_labels}
  defp validate_inputs(_, _), do: :ok

  defp load_nli_model(model_name, opts) do
    Logger.info("Loading NLI model for zero-shot: #{model_name}")

    case Loader.load_model(model_name, opts) do
      {:ok, model} ->
        {:ok, model}

      {:error, reason} ->
        Logger.warning("Failed to load #{model_name}: #{inspect(reason)}")
        {:error, {:model_load_failed, reason}}
    end
  end

  defp score_labels(model, text, candidate_labels, hypothesis_template) do
    # For each candidate label, create a hypothesis and score it
    scores =
      candidate_labels
      |> Enum.map(fn label ->
        hypothesis = String.replace(hypothesis_template, "{}", label)
        score = score_entailment(model, text, hypothesis)
        {label, score}
      end)
      |> Enum.into(%{})

    # Normalize scores to probabilities
    normalized_scores = normalize_scores(scores)

    {:ok, normalized_scores}
  end

  defp score_entailment(model, premise, hypothesis) do
    # Tokenize premise and hypothesis pair
    tokenizer = model.tokenizer

    # Format as NLI input: "[CLS] premise [SEP] hypothesis [SEP]"
    case tokenize_nli_pair(tokenizer, premise, hypothesis) do
      {:ok, inputs} ->
        # Run through NLI model
        case run_nli_inference(model, inputs) do
          {:ok, logits} ->
            # Extract entailment probability
            # NLI models typically output 3 classes: [contradiction, neutral, entailment]
            # We want the entailment probability (index 2)
            extract_entailment_score(logits)

          {:error, _reason} ->
            # Fallback to neutral score
            0.33
        end

      {:error, _reason} ->
        # Fallback to neutral score
        0.33
    end
  end

  defp tokenize_nli_pair(tokenizer, premise, hypothesis) do
    # Combine premise and hypothesis for NLI input
    combined_text = "#{premise} #{hypothesis}"

    case Bumblebee.apply_tokenizer(tokenizer, combined_text) do
      %{input_ids: input_ids, attention_mask: attention_mask} ->
        {:ok,
         %{
           input_ids: input_ids,
           attention_mask: attention_mask
         }}

      _error ->
        {:error, :tokenization_failed}
    end
  rescue
    _error -> {:error, :tokenization_failed}
  end

  defp run_nli_inference(model, inputs) do
    # Run the NLI model
    model_info = model.model_info

    case Axon.predict(model_info.model, model_info.params, inputs) do
      %{logits: logits} ->
        {:ok, logits}

      outputs when is_map(outputs) ->
        # Try to extract logits from different possible keys
        logits =
          Map.get(outputs, :logits) ||
            Map.get(outputs, "logits") ||
            Map.get(outputs, :output)

        if logits do
          {:ok, logits}
        else
          {:error, :no_logits_in_output}
        end

      _other ->
        {:error, :invalid_model_output}
    end
  rescue
    error -> {:error, {:inference_failed, error}}
  end

  defp extract_entailment_score(logits) do
    # Logits shape: [batch_size, num_classes] where num_classes = 3
    # Classes: [contradiction, neutral, entailment]
    # We want the probability of entailment (index 2)

    # Squeeze batch dimension if present
    logits =
      if Nx.rank(logits) == 2 do
        Nx.squeeze(logits, axes: [0])
      else
        logits
      end

    # Apply softmax to get probabilities
    probs = Nx.exp(logits) |> Nx.divide(Nx.sum(Nx.exp(logits)))

    # Extract entailment probability (last class)
    entailment_prob =
      probs
      |> Nx.slice_along_axis(-1, 1, axis: 0)
      |> Nx.to_number()

    entailment_prob
  rescue
    _error ->
      # Fallback to neutral score on any error
      0.33
  end

  defp normalize_scores(scores) do
    # Apply softmax normalization
    total = scores |> Map.values() |> Enum.map(&:math.exp/1) |> Enum.sum()

    scores
    |> Enum.map(fn {label, score} ->
      normalized = :math.exp(score) / total
      {label, Float.round(normalized, 4)}
    end)
    |> Enum.into(%{})
  end

  defp build_single_label_result(text, scores) do
    # Find label with highest score
    {best_label, _best_score} = Enum.max_by(scores, fn {_label, score} -> score end)

    %{
      label: best_label,
      scores: scores,
      sequence: text
    }
  end

  defp build_multi_label_result(text, scores, threshold) do
    # Select all labels above threshold
    selected_labels =
      scores
      |> Enum.filter(fn {_label, score} -> score >= threshold end)
      |> Enum.map(fn {label, _score} -> label end)
      |> Enum.sort_by(fn label -> -Map.get(scores, label) end)

    %{
      labels: selected_labels,
      scores: scores,
      sequence: text
    }
  end
end
