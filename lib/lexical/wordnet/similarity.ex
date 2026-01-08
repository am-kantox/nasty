defmodule Nasty.Lexical.WordNet.Similarity do
  @moduledoc """
  Semantic similarity metrics for WordNet synsets.

  Provides various algorithms for measuring semantic similarity between words or synsets
  based on their position in the WordNet hierarchy and their definitions.

  ## Metrics

  - **Path Similarity** - Based on shortest path length in hypernym hierarchy
  - **Wu-Palmer Similarity** - Based on depth of LCS (Least Common Subsumer)
  - **Lesk Similarity** - Based on definition overlap
  - **Depth** - Distance from root in taxonomy

  ## Example

      alias Nasty.Lexical.WordNet.Similarity

      # Compare "dog" and "cat"
      dog_synset = WordNet.synsets("dog", :noun) |> hd()
      cat_synset = WordNet.synsets("cat", :noun) |> hd()

      # Path similarity
      Similarity.path_similarity(dog_synset.id, cat_synset.id)  # ~0.2

      # Wu-Palmer similarity
      Similarity.wup_similarity(dog_synset.id, cat_synset.id)   # ~0.857
  """

  alias Nasty.Lexical.WordNet

  @type synset_id :: String.t()
  @type language :: atom()
  @type similarity_score :: float()

  @doc """
  Calculates path-based similarity between two synsets.

  Uses the shortest path length in the hypernym/hyponym hierarchy.
  Formula: `1 / (path_length + 1)`

  Returns a score from 0.0 to 1.0, where:
  - 1.0 = identical synsets
  - Higher values = more similar
  - 0.0 = no path exists

  ## Examples

      iex> Similarity.path_similarity("oewn-02084071-n", "oewn-02084071-n")  # dog == dog
      1.0

      iex> Similarity.path_similarity("oewn-02084071-n", "oewn-02083346-n")  # dog -> canine
      0.5
  """
  @spec path_similarity(synset_id(), synset_id(), language()) :: similarity_score()
  def path_similarity(synset1_id, synset2_id, language \\ :en)

  def path_similarity(same_id, same_id, _language), do: 1.0

  def path_similarity(synset1_id, synset2_id, language) do
    case WordNet.shortest_path(synset1_id, synset2_id, language) do
      nil -> 0.0
      0 -> 1.0
      path_length -> 1.0 / (path_length + 1)
    end
  end

  @doc """
  Calculates Wu-Palmer similarity between two synsets.

  Based on the depth of the Least Common Subsumer (LCS) and the depths
  of the two synsets in the taxonomy.

  Formula: `2 * depth(LCS) / (depth(synset1) + depth(synset2))`

  Returns a score from 0.0 to 1.0, where:
  - 1.0 = identical synsets or same depth
  - Higher values = more similar
  - 0.0 = no common ancestor

  This metric often gives more intuitive results than path similarity
  because it considers depth in the taxonomy.

  ## Examples

      iex> Similarity.wup_similarity("oewn-02084071-n", "oewn-02121620-n", :en)  # dog, cat
      0.857  # High similarity (both are carnivores)

      iex> Similarity.wup_similarity("oewn-02084071-n", "oewn-12345678-n", :en)  # dog, tree
      0.133  # Low similarity (different domains)
  """
  @spec wup_similarity(synset_id(), synset_id(), language()) :: similarity_score()
  def wup_similarity(synset1_id, synset2_id, language \\ :en)

  def wup_similarity(same_id, same_id, _language), do: 1.0

  def wup_similarity(synset1_id, synset2_id, language) do
    # Find Least Common Subsumer (LCS)
    lcs_list = WordNet.common_hypernyms(synset1_id, synset2_id, language)

    if Enum.empty?(lcs_list) do
      0.0
    else
      # Get the LCS with maximum depth (closest common ancestor)
      lcs = Enum.max_by(lcs_list, &depth(&1, language), fn -> hd(lcs_list) end)

      lcs_depth = depth(lcs, language)
      depth1 = depth(synset1_id, language)
      depth2 = depth(synset2_id, language)

      # Wu-Palmer formula
      2.0 * lcs_depth / (depth1 + depth2)
    end
  end

  @doc """
  Calculates Lesk similarity based on definition overlap.

  Measures similarity by counting overlapping words between synset definitions.
  This is context-based rather than hierarchy-based.

  Returns a score from 0.0 to 1.0, where:
  - Higher values = more overlapping words in definitions
  - 0.0 = no overlap

  ## Examples

      iex> Similarity.lesk_similarity("oewn-02084071-n", "oewn-02121620-n", :en)  # dog, cat
      0.15  # Some overlap in definitions (animal-related words)
  """
  @spec lesk_similarity(synset_id(), synset_id(), language()) :: similarity_score()
  def lesk_similarity(synset1_id, synset2_id, language \\ :en)

  def lesk_similarity(same_id, same_id, _language), do: 1.0

  def lesk_similarity(synset1_id, synset2_id, language) do
    synset1 = WordNet.synset(synset1_id, language)
    synset2 = WordNet.synset(synset2_id, language)

    if synset1 && synset2 do
      # Get words from definitions and examples
      words1 = extract_words(synset1)
      words2 = extract_words(synset2)

      # Calculate overlap
      overlap = MapSet.intersection(words1, words2) |> MapSet.size()
      total = max(MapSet.size(words1), MapSet.size(words2))

      if total > 0 do
        overlap / total
      else
        0.0
      end
    else
      0.0
    end
  end

  @doc """
  Calculates the depth of a synset in the taxonomy.

  Depth is measured as the length of the longest path from the synset
  to a root node (a synset with no hypernyms).

  Returns a non-negative integer representing depth.

  ## Examples

      iex> Similarity.depth("oewn-00001740-n", :en)  # entity (root)
      0

      iex> Similarity.depth("oewn-02084071-n", :en)  # dog
      13
  """
  @spec depth(synset_id(), language()) :: non_neg_integer()
  def depth(synset_id, language \\ :en) do
    calculate_depth(synset_id, language, MapSet.new())
  end

  @doc """
  Finds the Least Common Subsumer (LCS) of two synsets.

  The LCS is the most specific common ancestor (deepest common hypernym)
  of two synsets in the taxonomy.

  Returns the synset ID of the LCS, or nil if no common ancestor exists.

  ## Examples

      iex> Similarity.lcs("oewn-02084071-n", "oewn-02121620-n", :en)  # dog, cat
      "oewn-02075296-n"  # carnivore
  """
  @spec lcs(synset_id(), synset_id(), language()) :: synset_id() | nil
  def lcs(synset1_id, synset2_id, language \\ :en) do
    common = WordNet.common_hypernyms(synset1_id, synset2_id, language)

    if Enum.empty?(common) do
      nil
    else
      # Return the deepest (most specific) common ancestor
      Enum.max_by(common, &depth(&1, language))
    end
  end

  @doc """
  Combines multiple similarity metrics with optional weights.

  Returns a weighted average of specified similarity metrics.

  ## Options

  - `:metrics` - List of metrics to use (default: all)
  - `:weights` - Weights for each metric (default: equal weights)

  ## Examples

      iex> Similarity.combined_similarity(
      ...>   "oewn-02084071-n",
      ...>   "oewn-02121620-n",
      ...>   metrics: [:path, :wup, :lesk],
      ...>   weights: [0.3, 0.5, 0.2]
      ...> )
      0.654
  """
  @spec combined_similarity(synset_id(), synset_id(), language(), keyword()) ::
          similarity_score()
  def combined_similarity(synset1_id, synset2_id, language \\ :en, opts \\ []) do
    metrics = Keyword.get(opts, :metrics, [:path, :wup, :lesk])
    weights = Keyword.get(opts, :weights, List.duplicate(1.0 / length(metrics), length(metrics)))

    scores =
      Enum.map(metrics, fn metric ->
        case metric do
          :path -> path_similarity(synset1_id, synset2_id, language)
          :wup -> wup_similarity(synset1_id, synset2_id, language)
          :lesk -> lesk_similarity(synset1_id, synset2_id, language)
          _ -> 0.0
        end
      end)

    # Weighted average
    Enum.zip(scores, weights)
    |> Enum.map(fn {score, weight} -> score * weight end)
    |> Enum.sum()
  end

  @doc """
  Calculates similarity between two words (not synsets).

  Finds the maximum similarity across all synset pairs for the two words.

  ## Examples

      iex> Similarity.word_similarity("dog", "cat", :noun)
      0.857
  """
  @spec word_similarity(String.t(), String.t(), atom() | nil, language(), keyword()) ::
          similarity_score()
  def word_similarity(word1, word2, pos \\ nil, language \\ :en, opts \\ []) do
    metric = Keyword.get(opts, :metric, :wup)

    synsets1 = WordNet.synsets(word1, pos, language)
    synsets2 = WordNet.synsets(word2, pos, language)

    if Enum.empty?(synsets1) || Enum.empty?(synsets2) do
      0.0
    else
      # Find maximum similarity across all synset pairs
      for s1 <- synsets1, s2 <- synsets2 do
        case metric do
          :path -> path_similarity(s1.id, s2.id, language)
          :wup -> wup_similarity(s1.id, s2.id, language)
          :lesk -> lesk_similarity(s1.id, s2.id, language)
          _ -> 0.0
        end
      end
      |> Enum.max(fn -> 0.0 end)
    end
  end

  # Private helpers

  defp calculate_depth(synset_id, language, visited) do
    if MapSet.member?(visited, synset_id) do
      # Cycle detected, return 0
      0
    else
      hypernyms = WordNet.hypernyms(synset_id, language)

      if Enum.empty?(hypernyms) do
        # Root node
        0
      else
        # Max depth of all parent paths + 1
        new_visited = MapSet.put(visited, synset_id)

        hypernyms
        |> Enum.map(&calculate_depth(&1, language, new_visited))
        |> Enum.max()
        |> Kernel.+(1)
      end
    end
  end

  defp extract_words(synset) do
    # Extract words from definition and examples
    text = [synset.definition | synset.examples] |> Enum.join(" ")

    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.reject(&(&1 == "" || String.length(&1) < 3))
    |> MapSet.new()
  end
end
