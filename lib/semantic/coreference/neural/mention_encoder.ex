defmodule Nasty.Semantic.Coreference.Neural.MentionEncoder do
  @moduledoc """
  Neural mention encoder using BiLSTM with attention.

  Encodes mentions into fixed-size vector representations by processing
  the mention tokens and surrounding context through a bidirectional LSTM
  with attention mechanism.

  ## Architecture

  1. Token embeddings (GloVe or trainable)
  2. BiLSTM over context tokens
  3. Attention over mention span
  4. Concatenate: [mention_repr, head_word, context_repr]

  ## Example

      # Build model
      model = MentionEncoder.build_model(
        vocab_size: 50_000,
        embedding_dim: 100,
        hidden_dim: 128
      )

      # Encode mention
      encoding = MentionEncoder.encode_mention(
        model,
        params,
        mention_tokens,
        context_tokens,
        mention_span
      )
  """

  import Nx.Defn
  alias Axon
  alias Nasty.AST.Semantic.Mention
  alias Nasty.AST.Token

  @type model :: Axon.t()
  @type params :: map()
  @type encoding :: Nx.Tensor.t()

  @doc """
  Build the mention encoder model.

  ## Options

    - `:vocab_size` - Vocabulary size (required)
    - `:embedding_dim` - Embedding dimension (default: 100)
    - `:hidden_dim` - LSTM hidden dimension (default: 128)
    - `:context_window` - Context window size (default: 10)
    - `:dropout` - Dropout rate (default: 0.3)
    - `:use_pretrained` - Use pre-trained embeddings (default: false)

  ## Returns

  Axon model that takes token IDs and returns mention encodings
  """
  @spec build_model(keyword()) :: model()
  def build_model(opts \\ []) do
    vocab_size = Keyword.fetch!(opts, :vocab_size)
    embedding_dim = Keyword.get(opts, :embedding_dim, 100)
    hidden_dim = Keyword.get(opts, :hidden_dim, 128)
    dropout = Keyword.get(opts, :dropout, 0.3)

    # Input: [batch_size, sequence_length]
    input = Axon.input("token_ids", shape: {nil, nil})
    mention_mask = Axon.input("mention_mask", shape: {nil, nil})

    # Embedding layer
    embedded =
      input
      |> Axon.embedding(vocab_size, embedding_dim, name: "token_embedding")
      |> Axon.dropout(rate: dropout)

    # BiLSTM encoder
    {lstm_output, _state} =
      embedded
      |> Axon.lstm(hidden_dim,
        name: "bilstm",
        recurrent_initializer: :glorot_uniform,
        unroll: :static
      )

    # Bidirectional (concatenate forward and backward)
    bilstm =
      Axon.layer(
        fn x, _opts -> x end,
        [lstm_output],
        name: "bilstm_concat"
      )

    # Attention over mention span
    mention_repr =
      Axon.layer(
        &attention_pooling/2,
        [bilstm, mention_mask],
        name: "mention_attention"
      )

    # Context representation (mean pooling over full sequence)
    context_repr =
      Axon.layer(
        &mean_pooling/2,
        [bilstm],
        name: "context_pooling"
      )

    # Concatenate representations
    final =
      Axon.concatenate([mention_repr, context_repr], axis: -1)
      |> Axon.dense(hidden_dim * 2, name: "final_projection")
      |> Axon.activation(:tanh)
      |> Axon.dropout(rate: dropout)

    final
  end

  @doc """
  Encode a mention with its context.

  ## Parameters

    - `model` - Trained Axon model
    - `params` - Model parameters
    - `mention` - Mention struct
    - `context_tokens` - List of context tokens
    - `vocab` - Token to ID mapping

  ## Returns

  Tensor encoding of the mention [hidden_dim * 2]
  """
  @spec encode_mention(model(), params(), Mention.t(), [Token.t()], map()) :: encoding()
  def encode_mention(model, params, mention, context_tokens, vocab) do
    # Convert tokens to IDs
    token_ids = tokens_to_ids(context_tokens, vocab)

    # Create mention mask (1 for mention tokens, 0 for context)
    mention_mask = create_mention_mask(mention, context_tokens)

    # Prepare input
    input = %{
      "token_ids" => Nx.tensor([token_ids]),
      "mention_mask" => Nx.tensor([mention_mask])
    }

    # Forward pass
    Axon.predict(model, params, input)
    |> Nx.squeeze(axes: [0])
  end

  @doc """
  Batch encode multiple mentions.

  More efficient than encoding one at a time.

  ## Parameters

    - `model` - Trained Axon model
    - `params` - Model parameters
    - `mentions` - List of mentions with contexts
    - `vocab` - Token to ID mapping

  ## Returns

  Tensor of shape [batch_size, hidden_dim * 2]
  """
  @spec batch_encode_mentions(model(), params(), [{Mention.t(), [Token.t()]}], map()) ::
          Nx.Tensor.t()
  def batch_encode_mentions(model, params, mention_context_pairs, vocab) do
    # Convert all to tensors
    batch_data =
      Enum.map(mention_context_pairs, fn {mention, context_tokens} ->
        token_ids = tokens_to_ids(context_tokens, vocab)
        mention_mask = create_mention_mask(mention, context_tokens)
        {token_ids, mention_mask}
      end)

    # Pad sequences to same length
    {padded_ids, padded_masks} = pad_batch(batch_data)

    # Prepare input
    input = %{
      "token_ids" => Nx.tensor(padded_ids),
      "mention_mask" => Nx.tensor(padded_masks)
    }

    # Forward pass
    Axon.predict(model, params, input)
  end

  ## Private Functions

  # Attention pooling over mention span
  defnp attention_pooling(sequence, mask) do
    # sequence: [batch, seq_len, hidden]
    # mask: [batch, seq_len]

    # Compute attention scores
    mask_expanded = Nx.new_axis(mask, -1)
    masked_sequence = sequence * mask_expanded

    # Sum over mention tokens
    mention_sum = Nx.sum(masked_sequence, axes: [1])

    # Normalize by number of mention tokens
    mention_count = Nx.sum(mask, axes: [1]) |> Nx.new_axis(-1)
    mention_count = Nx.max(mention_count, 1.0)

    mention_sum / mention_count
  end

  # Mean pooling over sequence
  defnp mean_pooling(sequence, _mask) do
    # sequence: [batch, seq_len, hidden]
    Nx.mean(sequence, axes: [1])
  end

  # Convert tokens to vocabulary IDs
  defp tokens_to_ids(tokens, vocab) do
    Enum.map(tokens, fn token ->
      text = String.downcase(token.text)
      Map.get(vocab, text, Map.get(vocab, "<UNK>", 0))
    end)
  end

  # Create binary mask for mention tokens
  defp create_mention_mask(mention, context_tokens) do
    mention_start = mention.token_idx
    mention_end = mention_start + length(mention.tokens) - 1

    context_tokens
    |> Enum.with_index()
    |> Enum.map(fn {_token, idx} ->
      if idx >= mention_start and idx <= mention_end, do: 1.0, else: 0.0
    end)
  end

  # Pad batch to same length
  defp pad_batch(batch_data) do
    max_len =
      batch_data
      |> Enum.map(fn {ids, _} -> length(ids) end)
      |> Enum.max(fn -> 0 end)

    padded_ids =
      Enum.map(batch_data, fn {ids, _masks} ->
        ids ++ List.duplicate(0, max_len - length(ids))
      end)

    padded_masks =
      Enum.map(batch_data, fn {_ids, masks} ->
        masks ++ List.duplicate(0.0, max_len - length(masks))
      end)

    {padded_ids, padded_masks}
  end

  @doc """
  Build vocabulary from training data.

  ## Parameters

    - `documents` - OntoNotes documents
    - `min_count` - Minimum token frequency (default: 2)
    - `max_vocab_size` - Maximum vocabulary size (default: 50_000)

  ## Returns

  Map from token text to ID
  """
  @spec build_vocab([map()], keyword()) :: map()
  def build_vocab(documents, opts \\ []) do
    min_count = Keyword.get(opts, :min_count, 2)
    max_vocab_size = Keyword.get(opts, :max_vocab_size, 50_000)

    # Count token frequencies
    token_counts =
      documents
      |> Enum.flat_map(fn doc -> doc.sentences end)
      |> Enum.flat_map(fn sent -> sent.tokens end)
      |> Enum.map(fn token -> String.downcase(token.text) end)
      |> Enum.frequencies()

    # Filter by min count and take top K
    vocab_tokens =
      token_counts
      |> Enum.filter(fn {_token, count} -> count >= min_count end)
      |> Enum.sort_by(fn {_token, count} -> count end, :desc)
      |> Enum.take(max_vocab_size - 3)
      |> Enum.map(fn {token, _count} -> token end)

    # Build vocab map with special tokens
    [{"<PAD>", 0}, {"<UNK>", 1}, {"<START>", 2}]
    |> Enum.concat(Enum.with_index(vocab_tokens, 3))
    |> Enum.into(%{})
  end

  @doc """
  Load pre-trained GloVe embeddings.

  ## Parameters

    - `path` - Path to GloVe file (e.g., "glove.6B.100d.txt")
    - `vocab` - Vocabulary map
    - `embedding_dim` - Embedding dimension

  ## Returns

  Tensor of shape [vocab_size, embedding_dim] with pre-trained embeddings
  """
  @spec load_glove_embeddings(Path.t(), map(), pos_integer()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def load_glove_embeddings(path, vocab, embedding_dim) do
    if File.exists?(path) do
      # Read GloVe file and build embedding matrix
      embeddings =
        File.stream!(path)
        |> Stream.map(&parse_glove_line/1)
        |> Enum.reduce(%{}, fn {word, vector}, acc ->
          Map.put(acc, word, vector)
        end)

      # Build embedding matrix
      vocab_size = map_size(vocab)

      embedding_matrix =
        Enum.map(0..(vocab_size - 1), fn id ->
          # Find word for this ID
          word =
            Enum.find_value(vocab, fn {w, wid} ->
              if wid == id, do: w, else: nil
            end)

          # Get embedding or random init
          case Map.get(embeddings, word) do
            nil -> Enum.map(1..embedding_dim, fn _ -> :rand.normal() * 0.01 end)
            vector -> vector
          end
        end)

      {:ok, Nx.tensor(embedding_matrix)}
    else
      {:error, :file_not_found}
    end
  end

  # Parse a line from GloVe file
  defp parse_glove_line(line) do
    parts = String.split(line, " ")
    word = List.first(parts)
    vector = parts |> Enum.drop(1) |> Enum.map(&String.to_float/1)
    {word, vector}
  end
end
