defmodule Nasty.Semantic.Coreference.Neural.PairScorer do
  @moduledoc """
  Neural pairwise coreference scorer.

  Scores pairs of mentions for coreference likelihood using a feedforward
  network over mention representations and hand-crafted features.

  ## Architecture

  1. Concatenate mention encodings [m1, m2]
  2. Extract hand-crafted features
  3. Concatenate all features
  4. Feedforward network (2-3 hidden layers)
  5. Sigmoid output for probability

  ## Example

      # Build model
      model = PairScorer.build_model(
        mention_dim: 256,
        feature_dim: 20,
        hidden_dims: [512, 256]
      )

      # Score pair
      score = PairScorer.score_pair(
        model,
        params,
        mention1_encoding,
        mention2_encoding,
        features
      )
  """

  alias Axon
  alias Nasty.AST.Semantic.Mention

  @type model :: Axon.t()
  @type params :: map()
  @type features :: Nx.Tensor.t()

  @doc """
  Build the pair scorer model.

  ## Options

    - `:mention_dim` - Dimension of mention encodings (required)
    - `:feature_dim` - Number of hand-crafted features (default: 20)
    - `:hidden_dims` - List of hidden layer dimensions (default: [512, 256])
    - `:dropout` - Dropout rate (default: 0.3)

  ## Returns

  Axon model that takes mention pairs and features, returns coreference probability
  """
  @spec build_model(keyword()) :: model()
  def build_model(opts \\ []) do
    mention_dim = Keyword.fetch!(opts, :mention_dim)
    feature_dim = Keyword.get(opts, :feature_dim, 20)
    hidden_dims = Keyword.get(opts, :hidden_dims, [512, 256])
    dropout = Keyword.get(opts, :dropout, 0.3)

    # Inputs
    mention1 = Axon.input("mention1", shape: {nil, mention_dim})
    mention2 = Axon.input("mention2", shape: {nil, mention_dim})
    features = Axon.input("features", shape: {nil, feature_dim})

    # Concatenate all inputs
    combined =
      Axon.concatenate([mention1, mention2, features], axis: -1)

    # Build feedforward network
    hidden =
      Enum.reduce(hidden_dims, combined, fn dim, input ->
        input
        |> Axon.dense(dim, activation: :relu)
        |> Axon.dropout(rate: dropout)
      end)

    # Output layer (binary classification)
    output =
      hidden
      |> Axon.dense(1, activation: :sigmoid, name: "output")

    output
  end

  @doc """
  Score a pair of mentions for coreference.

  ## Parameters

    - `model` - Trained model
    - `params` - Model parameters
    - `mention1_encoding` - Encoding of first mention [mention_dim]
    - `mention2_encoding` - Encoding of second mention [mention_dim]
    - `features` - Hand-crafted features [feature_dim]

  ## Returns

  Probability that mentions corefer (0.0 to 1.0)
  """
  @spec score_pair(model(), params(), Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()) :: float()
  def score_pair(model, params, mention1_encoding, mention2_encoding, features) do
    input = %{
      "mention1" => Nx.new_axis(mention1_encoding, 0),
      "mention2" => Nx.new_axis(mention2_encoding, 0),
      "features" => Nx.new_axis(features, 0)
    }

    Axon.predict(model, params, input)
    |> Nx.to_flat_list()
    |> List.first()
  end

  @doc """
  Batch score multiple mention pairs.

  ## Parameters

    - `model` - Trained model
    - `params` - Model parameters
    - `pairs` - List of {m1_encoding, m2_encoding, features} tuples

  ## Returns

  Tensor of coreference probabilities [batch_size]
  """
  @spec batch_score_pairs(
          model(),
          params(),
          [{Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()}]
        ) :: Nx.Tensor.t()
  def batch_score_pairs(model, params, pairs) do
    {m1_batch, m2_batch, feat_batch} = unzip_pairs(pairs)

    input = %{
      "mention1" => Nx.stack(m1_batch),
      "mention2" => Nx.stack(m2_batch),
      "features" => Nx.stack(feat_batch)
    }

    Axon.predict(model, params, input)
    |> Nx.squeeze(axes: [1])
  end

  @doc """
  Extract hand-crafted features from mention pair.

  Features include:
  - Distance features (sentence, token, mention)
  - String match features (exact, partial, head)
  - Mention type features (pronoun, name, nominal)
  - Agreement features (gender, number)
  - Syntactic features (same sentence, same paragraph)

  ## Parameters

    - `mention1` - First mention
    - `mention2` - Second mention
    - `document` - Document context (optional, for additional features)

  ## Returns

  Feature vector as tensor [feature_dim]
  """
  @spec extract_features(Mention.t(), Mention.t(), map() | nil) :: Nx.Tensor.t()
  def extract_features(mention1, mention2, _document \\ nil) do
    features = [
      # Distance features (3 features)
      sentence_distance(mention1, mention2),
      token_distance(mention1, mention2),
      mention_distance(mention1, mention2),
      # String match features (3 features)
      exact_match(mention1, mention2),
      partial_match(mention1, mention2),
      head_match(mention1, mention2),
      # Mention type features (6 features)
      pronoun_feature(mention1),
      pronoun_feature(mention2),
      proper_name_feature(mention1),
      proper_name_feature(mention2),
      definite_np_feature(mention1),
      definite_np_feature(mention2),
      # Agreement features (4 features)
      gender_agreement(mention1, mention2),
      number_agreement(mention1, mention2),
      same_entity_type(mention1, mention2),
      # Positional features (4 features)
      same_sentence(mention1, mention2),
      first_mention(mention1),
      first_mention(mention2),
      pronoun_name_pair(mention1, mention2)
    ]

    Nx.tensor(features, type: :f32)
  end

  ## Private Feature Functions

  # Normalized sentence distance (0-1)
  defp sentence_distance(m1, m2) do
    dist = abs(m1.sentence_idx - m2.sentence_idx)
    # Normalize by max expected distance (e.g., 5 sentences)
    min(dist / 5.0, 1.0)
  end

  # Normalized token distance within sentence
  defp token_distance(m1, m2) do
    if m1.sentence_idx == m2.sentence_idx do
      dist = abs(m1.token_idx - m2.token_idx)
      min(dist / 20.0, 1.0)
    else
      1.0
    end
  end

  # Mention distance (how far apart in mention sequence)
  defp mention_distance(m1, m2) do
    # Approximate: use sentence + token as proxy
    dist = abs(m1.sentence_idx * 100 + m1.token_idx - (m2.sentence_idx * 100 + m2.token_idx))
    min(dist / 500.0, 1.0)
  end

  # Exact string match (case-insensitive)
  defp exact_match(m1, m2) do
    if String.downcase(m1.text) == String.downcase(m2.text), do: 1.0, else: 0.0
  end

  # Partial string match (one contains other)
  defp partial_match(m1, m2) do
    t1 = String.downcase(m1.text)
    t2 = String.downcase(m2.text)

    if String.contains?(t1, t2) or String.contains?(t2, t1), do: 1.0, else: 0.0
  end

  # Head word match
  defp head_match(m1, m2) do
    h1 = get_head_word(m1)
    h2 = get_head_word(m2)

    if h1 && h2 && String.downcase(h1) == String.downcase(h2), do: 1.0, else: 0.0
  end

  defp get_head_word(mention) do
    if Enum.empty?(mention.tokens) do
      nil
    else
      mention.tokens |> List.last() |> Map.get(:text)
    end
  end

  # Mention type indicators
  defp pronoun_feature(mention), do: if(Mention.pronoun?(mention), do: 1.0, else: 0.0)
  defp proper_name_feature(mention), do: if(Mention.proper_name?(mention), do: 1.0, else: 0.0)
  defp definite_np_feature(mention), do: if(Mention.definite_np?(mention), do: 1.0, else: 0.0)

  # Agreement features
  defp gender_agreement(m1, m2), do: if(Mention.gender_agrees?(m1, m2), do: 1.0, else: 0.0)
  defp number_agreement(m1, m2), do: if(Mention.number_agrees?(m1, m2), do: 1.0, else: 0.0)

  defp same_entity_type(m1, m2) do
    if m1.entity_type && m2.entity_type && m1.entity_type == m2.entity_type,
      do: 1.0,
      else: 0.0
  end

  # Positional features
  defp same_sentence(m1, m2), do: if(m1.sentence_idx == m2.sentence_idx, do: 1.0, else: 0.0)
  defp first_mention(mention), do: if(mention.sentence_idx == 0, do: 1.0, else: 0.0)

  # Pronoun-name pairing (common coreference pattern)
  defp pronoun_name_pair(m1, m2) do
    if (Mention.pronoun?(m1) and Mention.proper_name?(m2)) or
         (Mention.proper_name?(m1) and Mention.pronoun?(m2)),
       do: 1.0,
       else: 0.0
  end

  # Helper to unzip list of triples
  defp unzip_pairs(pairs) do
    {m1s, m2s, feats} =
      Enum.reduce(pairs, {[], [], []}, fn {m1, m2, feat}, {acc1, acc2, acc3} ->
        {[m1 | acc1], [m2 | acc2], [feat | acc3]}
      end)

    {Enum.reverse(m1s), Enum.reverse(m2s), Enum.reverse(feats)}
  end

  @doc """
  Get feature dimension (number of features extracted).
  """
  @spec feature_dim() :: pos_integer()
  def feature_dim, do: 20
end
