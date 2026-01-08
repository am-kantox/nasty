defmodule Nasty.Statistics.Neural.Transformers.DataPreprocessor do
  @moduledoc """
  Data preprocessing pipeline for fine-tuning transformer models.

  Transforms Nasty tokens into transformer-compatible inputs with:
  - Subword tokenization alignment
  - Padding and truncation to max sequence length
  - Attention mask generation
  - Label alignment for subword tokens

  ## Example

      alias Nasty.AST.Token
      alias Nasty.Statistics.Neural.Transformers.DataPreprocessor

      tokens = [
        %Token{text: "The", pos: :det},
        %Token{text: "cat", pos: :noun}
      ]

      label_map = %{det: 0, noun: 1}

      {:ok, batch} = DataPreprocessor.prepare_batch(
        tokens,
        tokenizer,
        label_map,
        max_length: 512
      )

  """

  alias Nasty.AST.Token

  @type tokenizer :: map()
  @type label_map :: %{atom() => integer()}
  @type batch :: %{
          input_ids: Nx.Tensor.t(),
          attention_mask: Nx.Tensor.t(),
          labels: Nx.Tensor.t()
        }

  @doc """
  Prepares a batch of token sequences for transformer input.

  ## Parameters

    * `token_sequences` - List of token lists
    * `tokenizer` - Bumblebee tokenizer
    * `label_map` - Map from POS tags/labels to integer IDs
    * `opts` - Options

  ## Options

    * `:max_length` - Maximum sequence length (default: 512)
    * `:padding` - Padding strategy (:max_length or :longest, default: :max_length)
    * `:truncation` - Enable truncation (default: true)
    * `:label_pad_id` - ID to use for padded labels (default: -100)

  ## Returns

    * `{:ok, batch}` - Preprocessed batch with tensors
    * `{:error, reason}` - Error during preprocessing
  """
  @spec prepare_batch([Token.t()], tokenizer(), label_map(), keyword()) ::
          {:ok, batch()} | {:error, term()}
  def prepare_batch(token_sequences, tokenizer, label_map, opts \\ [])

  def prepare_batch(token_sequences, tokenizer, label_map, opts)
      when is_list(token_sequences) do
    max_length = Keyword.get(opts, :max_length, 512)
    label_pad_id = Keyword.get(opts, :label_pad_id, -100)

    # Process each sequence
    processed =
      Enum.map(token_sequences, fn tokens ->
        process_sequence(tokens, tokenizer, label_map, max_length, label_pad_id)
      end)

    # Check for errors
    case Enum.find(processed, &match?({:error, _}, &1)) do
      {:error, reason} ->
        {:error, reason}

      nil ->
        # Extract components and stack into tensors
        results = Enum.map(processed, fn {:ok, result} -> result end)
        batch = stack_batch(results)
        {:ok, batch}
    end
  end

  def prepare_batch(_, _, _, _), do: {:error, :invalid_input}

  @doc """
  Tokenizes a single sequence and aligns labels with subword tokens.

  ## Parameters

    * `tokens` - List of Nasty tokens
    * `tokenizer` - Bumblebee tokenizer
    * `label_map` - Label to ID mapping
    * `max_length` - Maximum sequence length
    * `label_pad_id` - Padding ID for labels

  ## Returns

    * `{:ok, %{input_ids: list, attention_mask: list, labels: list}}`
    * `{:error, reason}`
  """
  @spec process_sequence([Token.t()], tokenizer(), label_map(), integer(), integer()) ::
          {:ok, map()} | {:error, term()}
  def process_sequence(tokens, tokenizer, label_map, max_length, label_pad_id) do
    # Extract text and labels
    words = Enum.map(tokens, & &1.text)
    labels = Enum.map(tokens, &get_label(&1, label_map))

    # Tokenize with Bumblebee
    case tokenize_words(words, tokenizer) do
      {:ok, encoding} ->
        # Align labels with subword tokens
        aligned_labels = align_labels(labels, encoding.word_ids, label_pad_id)

        # Apply padding/truncation
        input_ids = pad_or_truncate(encoding.input_ids, max_length, tokenizer.pad_token_id)

        attention_mask =
          pad_or_truncate(encoding.attention_mask, max_length, 0)

        final_labels = pad_or_truncate(aligned_labels, max_length, label_pad_id)

        {:ok,
         %{
           input_ids: input_ids,
           attention_mask: attention_mask,
           labels: final_labels
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Converts Nasty token to label ID using label map.

  Supports multiple label extraction strategies:
  - `:pos` - Part-of-speech tag
  - `:entity_type` - Named entity type
  - Custom key from token struct

  ## Examples

      iex> get_label(%Token{pos: :noun}, %{noun: 1})
      1

      iex> get_label(%Token{entity_type: :person}, %{person: 0}, :entity_type)
      0
  """
  @spec get_label(Token.t(), label_map(), atom()) :: integer()
  def get_label(token, label_map, key \\ :pos) do
    label = Map.get(token, key)
    Map.get(label_map, label, 0)
  end

  @doc """
  Aligns word-level labels with subword tokens.

  When a word is split into multiple subword tokens, the first subword
  gets the label and subsequent subwords get label_pad_id.

  ## Strategy

  - First subword of word: original label
  - Subsequent subwords: label_pad_id (ignored in loss)
  - Special tokens (CLS, SEP): label_pad_id

  ## Examples

      labels = [1, 2, 3]
      word_ids = [nil, 0, 0, 1, 2, 2, nil]  # nil = special token
      align_labels(labels, word_ids, -100)
      # => [-100, 1, -100, 2, 3, -100, -100]
  """
  @spec align_labels([integer()], [integer() | nil], integer()) :: [integer()]
  def align_labels(labels, word_ids, label_pad_id) do
    word_ids
    |> Enum.reduce({[], nil}, fn
      nil, {acc, _prev_word_id} ->
        # Special token
        {[label_pad_id | acc], nil}

      word_id, {acc, prev_word_id} ->
        if word_id == prev_word_id do
          # Continuation of previous word
          {[label_pad_id | acc], word_id}
        else
          # First subword of new word
          label = Enum.at(labels, word_id, label_pad_id)
          {[label | acc], word_id}
        end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @doc """
  Pads or truncates a sequence to target length.

  ## Examples

      iex> pad_or_truncate([1, 2, 3], 5, 0)
      [1, 2, 3, 0, 0]

      iex> pad_or_truncate([1, 2, 3, 4, 5], 3, 0)
      [1, 2, 3]
  """
  @spec pad_or_truncate([integer()], integer(), integer()) :: [integer()]
  def pad_or_truncate(sequence, target_length, pad_value) do
    current_length = length(sequence)

    cond do
      current_length == target_length ->
        sequence

      current_length < target_length ->
        # Pad
        padding = List.duplicate(pad_value, target_length - current_length)
        sequence ++ padding

      current_length > target_length ->
        # Truncate
        Enum.take(sequence, target_length)
    end
  end

  @doc """
  Creates label map from list of unique labels.

  ## Examples

      iex> create_label_map([:noun, :verb, :adj])
      %{noun: 0, verb: 1, adj: 2}
  """
  @spec create_label_map([atom()]) :: label_map()
  def create_label_map(labels) when is_list(labels) do
    labels
    |> Enum.uniq()
    |> Enum.with_index()
    |> Map.new()
  end

  @doc """
  Extracts all unique labels from token sequences.

  ## Examples

      tokens = [
        [%Token{pos: :noun}, %Token{pos: :verb}],
        [%Token{pos: :adj}, %Token{pos: :noun}]
      ]

      extract_labels(tokens)
      # => [:noun, :verb, :adj]
  """
  @spec extract_labels([[Token.t()]], atom()) :: [atom()]
  def extract_labels(token_sequences, key \\ :pos) do
    token_sequences
    |> List.flatten()
    |> Enum.map(&Map.get(&1, key))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Private functions

  defp tokenize_words(words, tokenizer) do
    # Join words with spaces for tokenization
    text = Enum.join(words, " ")

    # Tokenize using Bumblebee
    case Bumblebee.apply_tokenizer(tokenizer, text) do
      %{input_ids: input_ids, attention_mask: attention_mask} = encoding ->
        # Extract word_ids (which token belongs to which word)
        word_ids = get_word_ids(encoding, length(words))

        {:ok,
         %{
           input_ids: Nx.to_flat_list(input_ids),
           attention_mask: Nx.to_flat_list(attention_mask),
           word_ids: word_ids
         }}

      _error ->
        {:error, :tokenization_failed}
    end
  rescue
    _error -> {:error, :tokenization_failed}
  end

  defp get_word_ids(encoding, _num_words) do
    # Bumblebee doesn't directly provide word_ids, so we need to infer them
    # This is a simplified version - in production would use tokenizer's word_ids
    # For now, assume one-to-one mapping (will be enhanced)
    input_ids = Nx.to_flat_list(encoding.input_ids)

    Enum.map(0..(length(input_ids) - 1), fn
      0 -> nil
      i when i == length(input_ids) - 1 -> nil
      i -> i - 1
    end)
  end

  defp stack_batch(results) do
    # Stack lists into Nx tensors
    input_ids =
      results
      |> Enum.map(& &1.input_ids)
      |> Nx.tensor()

    attention_mask =
      results
      |> Enum.map(& &1.attention_mask)
      |> Nx.tensor()

    labels =
      results
      |> Enum.map(& &1.labels)
      |> Nx.tensor()

    %{
      input_ids: input_ids,
      attention_mask: attention_mask,
      labels: labels
    }
  end
end
