defmodule Nasty.Semantic.Coreference.Clusterer do
  @moduledoc """
  Generic clustering module for coreference resolution.

  Builds coreference chains from mentions using agglomerative clustering:
  1. Start with each mention in its own cluster
  2. Iteratively merge the best-scoring cluster pair
  3. Continue until no pairs score above threshold

  Supports different merge strategies (average, best, worst linkage).
  """

  alias Nasty.AST.Semantic.{CorefChain, Mention}
  alias Nasty.Semantic.Coreference.Scorer

  @doc """
  Builds coreference chains from mentions.

  Uses agglomerative clustering to group mentions that likely refer
  to the same entity.

  ## Parameters

    - `mentions` - List of all mentions from document
    - `opts` - Clustering options
      - `:min_score` - Minimum score threshold for merging (default: 0.3)
      - `:max_distance` - Maximum sentence distance (default: 3)
      - `:merge_strategy` - Linkage type (default: :average)
      - `:weights` - Custom scoring weights

  ## Returns

  List of CorefChain structs, each containing mentions referring to same entity.
  Chains with only 1 mention are filtered out.

  ## Examples

      iex> mentions = [m1, m2, m3, m4]
      iex> chains = Clusterer.build_chains(mentions, min_score: 0.3)
      [
        %CorefChain{mentions: [m1, m2], representative: "John"},
        %CorefChain{mentions: [m3, m4], representative: "the cat"}
      ]
  """
  @spec build_chains([Mention.t()], keyword()) :: [CorefChain.t()]
  def build_chains(mentions, opts \\ []) do
    min_score = Keyword.get(opts, :min_score, 0.3)

    # Start with each mention in its own cluster
    clusters = Enum.map(mentions, fn m -> [m] end)

    # Iteratively merge clusters
    final_clusters = merge_clusters(clusters, opts, min_score)

    # Convert to chains
    final_clusters
    |> Enum.with_index(1)
    |> Enum.map(fn {cluster, id} ->
      representative = select_representative(cluster)
      entity_type = get_cluster_entity_type(cluster)

      CorefChain.new(id, cluster, representative, entity_type: entity_type)
    end)
    |> Enum.reject(fn chain -> CorefChain.mention_count(chain) < 2 end)
  end

  @doc """
  Merges clusters iteratively until no more merges are possible.

  Finds the best-scoring cluster pair at each iteration and merges them.
  Stops when no pair scores above min_score threshold.
  """
  @spec merge_clusters([[Mention.t()]], keyword(), float()) :: [[Mention.t()]]
  def merge_clusters(clusters, opts, min_score) do
    case find_best_merge(clusters, opts, min_score) do
      {:ok, {idx1, idx2}} ->
        # Merge the two clusters
        cluster1 = Enum.at(clusters, idx1)
        cluster2 = Enum.at(clusters, idx2)
        merged = cluster1 ++ cluster2

        # Remove old clusters and add merged one
        new_clusters =
          clusters
          |> Enum.with_index()
          |> Enum.reject(fn {_c, i} -> i == idx1 or i == idx2 end)
          |> Enum.map(fn {c, _i} -> c end)
          |> then(fn cs -> [merged | cs] end)

        # Continue merging
        merge_clusters(new_clusters, opts, min_score)

      :none ->
        # No more merges possible
        clusters
    end
  end

  @doc """
  Finds the best pair of clusters to merge.

  Scores all cluster pairs and returns indices of the pair with highest score
  above the minimum threshold.

  Returns {:ok, {idx1, idx2}} or :none if no valid merge exists.
  """
  @spec find_best_merge([[Mention.t()]], keyword(), float()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | :none
  def find_best_merge(clusters, opts, min_score) do
    # Score all cluster pairs
    pairs =
      for {c1, i1} <- Enum.with_index(clusters),
          {c2, i2} <- Enum.with_index(clusters),
          i1 < i2 do
        score = Scorer.score_cluster_pair(c1, c2, opts)
        {{i1, i2}, score}
      end

    # Find best scoring pair above threshold
    case Enum.max_by(pairs, fn {_pair, score} -> score end, fn -> nil end) do
      {pair, score} when score >= min_score -> {:ok, pair}
      _ -> :none
    end
  end

  @doc """
  Selects the representative mention for a cluster.

  Uses the following priority:
  1. First proper name (most specific)
  2. First definite NP (next most specific)
  3. First mention (fallback)

  ## Examples

      iex> cluster = [pronoun_mention, name_mention, np_mention]
      iex> Clusterer.select_representative(cluster)
      "John"  # The proper name
  """
  @spec select_representative([Mention.t()]) :: String.t()
  def select_representative(cluster) do
    # Try to find proper name first
    proper_name = Enum.find(cluster, &Mention.proper_name?/1)

    if proper_name do
      proper_name.text
    else
      # Try definite NP
      definite_np = Enum.find(cluster, &Mention.definite_np?/1)

      if definite_np do
        definite_np.text
      else
        # Fallback to first mention
        first = List.first(cluster)
        if first, do: first.text, else: ""
      end
    end
  end

  ## Private Helpers

  # Get entity type for cluster (from first mention with entity type)
  defp get_cluster_entity_type(cluster) do
    cluster
    |> Enum.find(fn m -> m.entity_type != nil end)
    |> case do
      %Mention{entity_type: type} -> type
      nil -> nil
    end
  end
end
