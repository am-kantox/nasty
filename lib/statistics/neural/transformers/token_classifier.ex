defmodule Nasty.Statistics.Neural.Transformers.TokenClassifier do
  @moduledoc """
  Token classification layer on top of pre-trained transformers.

  Supports:
  - Part-of-speech (POS) tagging
  - Named Entity Recognition (NER)
  - Custom token classification tasks

  The classifier adds a linear layer on top of transformer encoder outputs
  and uses softmax for multi-class classification per token.
  """

  alias Nasty.AST.Token
  alias Nasty.Statistics.Neural.Transformers.TokenizerAdapter

  require Nx

  @type task :: :pos_tagging | :ner | :token_classification

  @type classifier_config :: %{
          task: task(),
          num_labels: integer(),
          label_map: %{integer() => String.t()},
          model_name: atom(),
          dropout_rate: float()
        }

  @type classifier :: %{
          base_model: map(),
          config: classifier_config(),
          classification_head: Axon.t()
        }

  @type prediction :: %{
          token_index: integer(),
          label: String.t(),
          label_id: integer(),
          score: float()
        }

  @doc """
  Creates a token classifier from a pre-trained transformer model.

  ## Options

    * `:task` - Classification task (:pos_tagging, :ner, or :token_classification)
    * `:num_labels` - Number of classification labels
    * `:label_map` - Map from label IDs to label names
    * `:dropout_rate` - Dropout rate for classification head (default: 0.1)

  ## Examples

      {:ok, base_model} = Loader.load_model(:roberta_base)
      {:ok, classifier} = TokenClassifier.create(base_model,
        task: :pos_tagging,
        num_labels: 17,
        label_map: %{0 => "NOUN", 1 => "VERB", ...}
      )

  """
  @spec create(map(), keyword()) :: {:ok, classifier()} | {:error, term()}
  def create(base_model, opts) do
    task = Keyword.fetch!(opts, :task)
    num_labels = Keyword.fetch!(opts, :num_labels)
    label_map = Keyword.fetch!(opts, :label_map)
    dropout_rate = Keyword.get(opts, :dropout_rate, 0.1)

    config = %{
      task: task,
      num_labels: num_labels,
      label_map: label_map,
      model_name: base_model.name,
      dropout_rate: dropout_rate
    }

    # Build classification head
    hidden_size = base_model.config.hidden_size
    classification_head = build_classification_head(hidden_size, num_labels, dropout_rate)

    classifier = %{
      base_model: base_model,
      config: config,
      classification_head: classification_head
    }

    {:ok, classifier}
  end

  @doc """
  Predicts labels for a sequence of tokens.

  Returns predictions with label names and confidence scores.

  ## Examples

      {:ok, predictions} = TokenClassifier.predict(classifier, tokens)
      # => [
      #   %{token_index: 0, label: "NOUN", label_id: 0, score: 0.95},
      #   %{token_index: 1, label: "VERB", label_id: 1, score: 0.89},
      #   ...
      # ]

  """
  @spec predict(classifier(), [Token.t()], keyword()) ::
          {:ok, [prediction()]} | {:error, term()}
  def predict(classifier, tokens, opts \\ []) do
    strategy = Keyword.get(opts, :alignment_strategy, :first)

    with {:ok, tokenizer_output} <-
           TokenizerAdapter.tokenize_for_transformer(
             tokens,
             classifier.base_model.tokenizer,
             opts
           ),
         {:ok, logits} <- forward_pass(classifier, tokenizer_output) do
      align_and_decode(logits, tokenizer_output, classifier.config, strategy)
    end
  end

  @doc """
  Predicts labels for multiple sequences in batch.

  More efficient than calling predict/3 multiple times.

  ## Examples

      {:ok, batch_predictions} = TokenClassifier.predict_batch(classifier, [tokens1, tokens2])

  """
  @spec predict_batch(classifier(), [[Token.t()]], keyword()) ::
          {:ok, [[prediction()]]} | {:error, term()}
  def predict_batch(classifier, token_sequences, opts \\ []) do
    # Process each sequence
    results =
      Enum.map(token_sequences, fn tokens ->
        predict(classifier, tokens, opts)
      end)

    # Check if all succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      predictions = Enum.map(results, fn {:ok, preds} -> preds end)
      {:ok, predictions}
    else
      first_error = Enum.find(results, &match?({:error, _}, &1))
      first_error
    end
  end

  @doc """
  Updates tokens with predicted labels.

  Modifies the token structs to include predicted POS tags or entity labels.

  ## Examples

      {:ok, tagged_tokens} = TokenClassifier.tag_tokens(classifier, tokens, task: :pos_tagging)

  """
  @spec tag_tokens(classifier(), [Token.t()], keyword()) ::
          {:ok, [Token.t()]} | {:error, term()}
  def tag_tokens(classifier, tokens, opts \\ []) do
    task = Keyword.get(opts, :task, classifier.config.task)

    with {:ok, predictions} <- predict(classifier, tokens, opts) do
      tagged =
        Enum.zip(tokens, predictions)
        |> Enum.map(fn {token, pred} ->
          update_token_with_prediction(token, pred, task)
        end)

      {:ok, tagged}
    end
  end

  # Private functions

  defp build_classification_head(hidden_size, num_labels, dropout_rate) do
    # Simple linear classification head:
    # hidden_states -> dropout -> linear -> softmax
    Axon.input("hidden_states", shape: {nil, nil, hidden_size})
    |> Axon.dropout(rate: dropout_rate)
    |> Axon.dense(num_labels, name: "classifier")
  end

  defp forward_pass(classifier, tokenizer_output) do
    # Get base model spec and params
    base_model_info = classifier.base_model.model_info

    # Forward pass through transformer
    inputs = %{
      "input_ids" => tokenizer_output.input_ids,
      "attention_mask" => tokenizer_output.attention_mask
    }

    # Use Bumblebee to run the model
    {:ok, outputs} = apply_base_model(base_model_info, inputs)

    # Extract hidden states (last layer)
    hidden_states = get_hidden_states(outputs)

    # Apply classification head
    logits = apply_classification_head(classifier.classification_head, hidden_states)

    {:ok, logits}
  rescue
    error ->
      {:error, {:forward_pass_failed, error}}
  end

  defp apply_base_model(_model_info, inputs) do
    # This is a simplified version - in practice, we'd use Bumblebee.apply_model
    # or create a serving for inference
    # For now, return a placeholder that we'll implement properly during integration

    # Extract dimensions from inputs
    batch_size = inputs["input_ids"] |> Nx.shape() |> elem(0)
    seq_length = inputs["input_ids"] |> Nx.shape() |> elem(1)
    # Standard BERT/RoBERTa hidden size
    hidden_size = 768

    # Return mock hidden states for now
    # TODO: Replace with actual Bumblebee.apply_model call
    # Use a deterministic approach instead of random
    hidden_states = Nx.broadcast(0.0, {batch_size, seq_length, hidden_size})

    {:ok, %{hidden_state: hidden_states}}
  end

  defp get_hidden_states(outputs) do
    # Extract last hidden state from model outputs
    Map.get(outputs, :hidden_state) || Map.get(outputs, :last_hidden_state)
  end

  defp apply_classification_head(_head_model, hidden_states) do
    # Apply the classification head to get logits
    # For now, use random values - will be replaced with actual Axon execution
    {batch_size, seq_length, _hidden_size} = Nx.shape(hidden_states)
    # Default to UPOS tag count
    num_labels = 17

    # TODO: Execute Axon model properly
    # Use deterministic approach instead of random
    Nx.broadcast(0.0, {batch_size, seq_length, num_labels})
  end

  defp align_and_decode(logits, tokenizer_output, config, strategy) do
    # Convert logits to predictions
    predictions = logits_to_predictions(logits)

    # Remove special tokens
    real_predictions =
      TokenizerAdapter.remove_special_tokens(
        predictions,
        tokenizer_output.special_token_mask
      )

    # Align subword predictions to original tokens
    aligned =
      TokenizerAdapter.align_predictions(
        real_predictions,
        tokenizer_output.alignment_map,
        strategy: strategy
      )

    # Add labels and format
    formatted =
      aligned
      |> Enum.with_index()
      |> Enum.map(fn {pred, idx} ->
        %{
          token_index: idx,
          label: Map.get(config.label_map, pred.label_id, "UNK"),
          label_id: pred.label_id,
          score: pred.score
        }
      end)

    {:ok, formatted}
  end

  defp logits_to_predictions(logits) do
    # Convert logits tensor to predictions
    # Shape: [batch_size, seq_len, num_labels]

    # Squeeze batch dimension (assume batch_size = 1)
    logits = Nx.squeeze(logits, axes: [0])

    # Get shape info
    {seq_len, _num_labels} = Nx.shape(logits)

    # For each position, get argmax and softmax score
    0..(seq_len - 1)
    |> Enum.map(fn pos ->
      # Extract logits for this position
      position_logits = logits[pos]

      # Get predicted label (argmax)
      label_id = position_logits |> Nx.argmax() |> Nx.to_number()

      # Get confidence score (softmax)
      probs = Nx.exp(position_logits) |> Nx.divide(Nx.sum(Nx.exp(position_logits)))
      score = probs[label_id] |> Nx.to_number()

      %{label_id: label_id, score: score}
    end)
  end

  defp update_token_with_prediction(token, prediction, :pos_tagging) do
    %{token | pos_tag: String.to_atom(prediction.label)}
  end

  defp update_token_with_prediction(token, prediction, :ner) do
    %{token | entity_label: prediction.label}
  end

  defp update_token_with_prediction(token, prediction, :token_classification) do
    # Generic classification - store in metadata
    metadata = Map.get(token, :metadata, %{})
    updated_metadata = Map.put(metadata, :classification, prediction)
    %{token | metadata: updated_metadata}
  end
end
