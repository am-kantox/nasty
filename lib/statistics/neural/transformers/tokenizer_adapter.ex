defmodule Nasty.Statistics.Neural.Transformers.TokenizerAdapter do
  @moduledoc """
  Bridges between Nasty's word-level tokens and transformer subword tokenization.

  Transformers use subword tokenization (BPE, WordPiece) which splits words into
  multiple tokens. This module handles:
  - Converting Nasty tokens to transformer input
  - Aligning transformer predictions back to original tokens
  - Managing special tokens ([CLS], [SEP], etc.)
  """

  alias Nasty.AST.Token

  @type alignment_map :: %{integer() => subword_range()}

  @type subword_range :: {start_index :: integer(), end_index :: integer()}

  @type tokenizer_output :: %{
          input_ids: Nx.Tensor.t(),
          attention_mask: Nx.Tensor.t(),
          alignment_map: alignment_map(),
          special_token_mask: [boolean()]
        }

  @doc """
  Tokenizes Nasty tokens for transformer input.

  Returns input tensors and an alignment map that tracks which subword tokens
  correspond to which original tokens.

  ## Options

    * `:max_length` - Maximum sequence length (default: 512)
    * `:padding` - Padding strategy: `:max_length` or `:none` (default: `:max_length`)
    * `:truncation` - Whether to truncate long sequences (default: true)

  ## Examples

      {:ok, output} = TokenizerAdapter.tokenize_for_transformer(tokens, tokenizer)
      # => %{
      #   input_ids: #Nx.Tensor<...>,
      #   attention_mask: #Nx.Tensor<...>,
      #   alignment_map: %{0 => {1, 2}, 1 => {3, 3}, ...},
      #   special_token_mask: [true, false, false, ...]
      # }

  """
  @spec tokenize_for_transformer([Token.t()], map(), keyword()) ::
          {:ok, tokenizer_output()} | {:error, term()}
  def tokenize_for_transformer(tokens, tokenizer, opts \\ []) do
    max_length = Keyword.get(opts, :max_length, 512)
    padding = Keyword.get(opts, :padding, :max_length)
    truncation = Keyword.get(opts, :truncation, true)

    # Extract text from tokens
    text_chunks = Enum.map(tokens, & &1.text)

    # Tokenize with Bumblebee tokenizer
    # We tokenize each word separately to maintain alignment
    with {:ok, subword_tokens, alignment_map} <-
           tokenize_with_alignment(text_chunks, tokenizer, max_length, truncation),
         {:ok, input_ids, attention_mask, special_token_mask} <-
           build_tensors(subword_tokens, tokenizer, max_length, padding) do
      {:ok,
       %{
         input_ids: input_ids,
         attention_mask: attention_mask,
         alignment_map: alignment_map,
         special_token_mask: special_token_mask
       }}
    end
  end

  @doc """
  Aligns transformer predictions back to original tokens.

  Takes predictions for each subword token and aggregates them to produce
  one prediction per original token.

  ## Strategies

    * `:first` - Use prediction from first subword (default)
    * `:average` - Average predictions across all subwords
    * `:max` - Use maximum prediction across subwords

  ## Examples

      predictions = align_predictions(subword_preds, alignment_map, strategy: :first)
      # => [%{label: "NOUN", score: 0.95}, ...]

  """
  @spec align_predictions(Nx.Tensor.t() | [map()], alignment_map(), keyword()) ::
          [map()] | {:error, term()}
  def align_predictions(subword_predictions, alignment_map, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :first)

    # Convert tensor to list of predictions if needed
    predictions =
      if is_struct(subword_predictions, Nx.Tensor) do
        tensor_to_predictions(subword_predictions)
      else
        subword_predictions
      end

    # Aggregate predictions per original token
    num_tokens = map_size(alignment_map)

    Enum.map(0..(num_tokens - 1), fn token_idx ->
      {start_idx, end_idx} = Map.fetch!(alignment_map, token_idx)
      subword_preds = Enum.slice(predictions, start_idx, end_idx - start_idx + 1)

      aggregate_predictions(subword_preds, strategy)
    end)
  end

  @doc """
  Extracts only predictions for real tokens (ignoring special tokens).

  ## Examples

      real_predictions = remove_special_tokens(predictions, special_token_mask)

  """
  @spec remove_special_tokens([map()], [boolean()]) :: [map()]
  def remove_special_tokens(predictions, special_token_mask) do
    predictions
    |> Enum.zip(special_token_mask)
    |> Enum.reject(fn {_pred, is_special} -> is_special end)
    |> Enum.map(fn {pred, _} -> pred end)
  end

  # Private functions

  defp tokenize_with_alignment(text_chunks, tokenizer, max_length, truncation) do
    # Tokenize each word separately to maintain alignment
    {subword_tokens, alignment_map} =
      text_chunks
      |> Enum.with_index()
      |> Enum.reduce({[], %{}}, fn {text, token_idx}, {acc_tokens, acc_map} ->
        # Tokenize this word
        {:ok, word_tokens} = tokenize_word(text, tokenizer)

        # Calculate subword indices
        start_idx = length(acc_tokens) + 1
        end_idx = start_idx + length(word_tokens) - 1

        # Update alignment map
        new_map = Map.put(acc_map, token_idx, {start_idx, end_idx})

        # Accumulate tokens
        {acc_tokens ++ word_tokens, new_map}
      end)

    # Check truncation
    if truncation and length(subword_tokens) > max_length - 2 do
      # Account for [CLS] and [SEP] tokens
      truncated_tokens = Enum.take(subword_tokens, max_length - 2)

      # Adjust alignment map to remove truncated tokens
      adjusted_map =
        alignment_map
        |> Enum.filter(fn {_idx, {start_idx, _end_idx}} -> start_idx < max_length - 1 end)
        |> Enum.into(%{})

      {:ok, truncated_tokens, adjusted_map}
    else
      {:ok, subword_tokens, alignment_map}
    end
  end

  defp tokenize_word(text, tokenizer) do
    # Use Bumblebee to tokenize a single word
    # This returns token IDs for the word (may be multiple subwords)
    encoding = Bumblebee.apply_tokenizer(tokenizer, text)

    case encoding do
      %{input_ids: input_ids} ->
        # Remove special tokens ([CLS], [SEP]) that Bumblebee adds
        token_ids =
          input_ids
          |> Nx.to_flat_list()
          |> remove_bumblebee_special_tokens(tokenizer)

        {:ok, token_ids}

      _ ->
        {:error, :tokenization_failed}
    end
  end

  defp remove_bumblebee_special_tokens(token_ids, tokenizer) do
    # Remove [CLS] (typically 101 for BERT) and [SEP] (typically 102)
    # This is model-specific, so we check the tokenizer config
    special_ids = get_special_token_ids(tokenizer)

    Enum.reject(token_ids, fn id -> id in special_ids end)
  end

  defp get_special_token_ids(tokenizer) do
    # Extract special token IDs from tokenizer spec
    # Bumblebee tokenizers have this in their config
    Map.get(tokenizer, :special_tokens, %{})
    |> Map.values()
    |> List.flatten()
  end

  defp build_tensors(subword_tokens, tokenizer, max_length, padding) do
    # Add [CLS] at start and [SEP] at end
    cls_id = get_cls_id(tokenizer)
    sep_id = get_sep_id(tokenizer)
    pad_id = get_pad_id(tokenizer)

    # Build token sequence
    token_sequence = [cls_id] ++ subword_tokens ++ [sep_id]
    sequence_length = length(token_sequence)

    # Build special token mask (true for special tokens)
    special_mask = [true] ++ List.duplicate(false, length(subword_tokens)) ++ [true]

    # Apply padding if needed
    {padded_tokens, padded_mask, padded_special_mask} =
      case padding do
        :max_length when sequence_length < max_length ->
          padding_length = max_length - sequence_length
          padded = token_sequence ++ List.duplicate(pad_id, padding_length)
          mask = List.duplicate(1, sequence_length) ++ List.duplicate(0, padding_length)

          special_mask_padded =
            special_mask ++ List.duplicate(true, padding_length)

          {padded, mask, special_mask_padded}

        _ ->
          mask = List.duplicate(1, sequence_length)
          {token_sequence, mask, special_mask}
      end

    # Convert to tensors
    input_ids = Nx.tensor([padded_tokens])
    attention_mask = Nx.tensor([padded_mask])

    {:ok, input_ids, attention_mask, padded_special_mask}
  end

  defp get_cls_id(tokenizer), do: Map.get(tokenizer, :cls_token_id, 101)
  defp get_sep_id(tokenizer), do: Map.get(tokenizer, :sep_token_id, 102)
  defp get_pad_id(tokenizer), do: Map.get(tokenizer, :pad_token_id, 0)

  defp tensor_to_predictions(tensor) do
    # Convert logits tensor [batch_size, seq_len, num_labels] to predictions
    # Assumes batch_size = 1
    tensor
    |> Nx.squeeze(axes: [0])
    |> Nx.to_batched(1)
    |> Enum.map(fn logits ->
      # Get argmax for label
      label_id = logits |> Nx.argmax() |> Nx.to_number()

      # Get softmax probabilities
      probs = Nx.exp(logits) |> Nx.divide(Nx.sum(Nx.exp(logits)))
      max_prob = probs |> Nx.reduce_max() |> Nx.to_number()

      %{label_id: label_id, score: max_prob}
    end)
  end

  defp aggregate_predictions(subword_preds, :first) do
    # Use prediction from first subword token
    List.first(subword_preds)
  end

  defp aggregate_predictions(subword_preds, :average) do
    # Average probabilities across subwords
    if Enum.empty?(subword_preds) do
      %{label_id: 0, score: 0.0}
    else
      avg_score =
        Enum.map(subword_preds, & &1.score) |> Enum.sum() |> Kernel./(length(subword_preds))

      # Use label from first subword (or could use voting)
      label_id = List.first(subword_preds).label_id

      %{label_id: label_id, score: avg_score}
    end
  end

  defp aggregate_predictions(subword_preds, :max) do
    # Use prediction with highest score
    Enum.max_by(subword_preds, & &1.score, fn -> %{label_id: 0, score: 0.0} end)
  end
end
