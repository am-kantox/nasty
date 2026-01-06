defmodule Nasty.Statistics.POSTagging.HMMTagger do
  @moduledoc """
  Hidden Markov Model (HMM) for Part-of-Speech tagging.

  Uses Viterbi algorithm for decoding the most likely tag sequence.
  Implements trigram transitions for better context modeling.

  ## Model Components

  - **Emission probabilities**: P(word|tag) - likelihood of a word given a tag
  - **Transition probabilities**: P(tag_i|tag_{i-1}, tag_{i-2}) - trigram model
  - **Initial probabilities**: P(tag) at sentence start
  - **Smoothing**: Add-k smoothing for unknown words and transitions

  ## Training

      # Train from POS-tagged sequences
      model = HMMTagger.new()
      training_data = [{["The", "cat"], [:det, :noun]}, ...]
      {:ok, trained_model} = HMMTagger.train(model, training_data, [])

  ## Prediction

      {:ok, tags} = HMMTagger.predict(model, ["The", "cat", "sat"], [])
      # => [:det, :noun, :verb]

  @behaviour Nasty.Statistics.Model
  """

  @behaviour Nasty.Statistics.Model

  alias Nasty.Statistics.Model

  defstruct [
    :emission_probs,
    # %{word => %{tag => prob}}
    :transition_probs,
    # %{{tag1, tag2} => %{tag3 => prob}}
    :initial_probs,
    # %{tag => prob}
    :tag_set,
    # MapSet of all tags
    :vocabulary,
    # MapSet of all words
    :smoothing_k,
    # Smoothing constant
    :metadata
    # Training metadata
  ]

  @type t :: %__MODULE__{
          emission_probs: map(),
          transition_probs: map(),
          initial_probs: map(),
          tag_set: MapSet.t(),
          vocabulary: MapSet.t(),
          smoothing_k: float(),
          metadata: map()
        }

  @doc """
  Create a new untrained HMM tagger.

  ## Options

    - `:smoothing_k` - Smoothing constant (default: 0.001)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      emission_probs: %{},
      transition_probs: %{},
      initial_probs: %{},
      tag_set: MapSet.new(),
      vocabulary: MapSet.new(),
      smoothing_k: Keyword.get(opts, :smoothing_k, 0.001),
      metadata: %{}
    }
  end

  @impl true
  @doc """
  Train the HMM on POS-tagged sequences.

  ## Parameters

    - `model` - Untrained or partially trained model
    - `training_data` - List of `{words, tags}` tuples
    - `opts` - Training options (currently unused)

  ## Returns

    - `{:ok, trained_model}` - Model with learned probabilities
  """
  @spec train(t(), [{[String.t()], [atom()]}], keyword()) :: {:ok, t()} | {:error, term()}
  def train(model, training_data, _opts \\ []) do
    # Count occurrences
    {emission_counts, transition_counts, initial_counts, tag_set, vocabulary} =
      count_statistics(training_data)

    # Convert counts to probabilities with smoothing
    emission_probs = normalize_emissions(emission_counts, tag_set, vocabulary, model.smoothing_k)

    transition_probs =
      normalize_transitions(transition_counts, tag_set, model.smoothing_k)

    initial_probs = normalize_initial(initial_counts, tag_set, model.smoothing_k)

    trained_model = %{
      model
      | emission_probs: emission_probs,
        transition_probs: transition_probs,
        initial_probs: initial_probs,
        tag_set: tag_set,
        vocabulary: vocabulary,
        metadata: %{
          trained_at: DateTime.utc_now(),
          training_size: length(training_data),
          num_tags: MapSet.size(tag_set),
          vocab_size: MapSet.size(vocabulary)
        }
    }

    {:ok, trained_model}
  end

  @impl true
  @doc """
  Predict POS tags for a sequence of words using Viterbi algorithm.

  ## Parameters

    - `model` - Trained HMM model
    - `words` - List of words to tag
    - `opts` - Prediction options (currently unused)

  ## Returns

    - `{:ok, tags}` - Most likely tag sequence
  """
  @spec predict(t(), [String.t()], keyword()) :: {:ok, [atom()]} | {:error, term()}
  def predict(model, words, opts \\ []) do
    case Keyword.get(opts, :algorithm, :viterbi) do
      :viterbi -> {:ok, viterbi(model, words)}
      other -> {:error, {:unsupported_algorithm, other}}
    end
  end

  @impl true
  @doc """
  Save the trained model to disk.
  """
  @spec save(t(), Path.t()) :: :ok | {:error, term()}
  def save(model, path) do
    binary = Model.serialize(model, model.metadata)

    case File.write(path, binary) do
      :ok -> :ok
      {:error, reason} -> {:error, {:file_write_failed, reason}}
    end
  end

  @impl true
  @doc """
  Load a trained model from disk.
  """
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    case File.read(path) do
      {:ok, binary} ->
        case Model.deserialize(binary) do
          {:ok, model, _metadata} -> {:ok, model}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, {:file_read_failed, reason}}
    end
  end

  @impl true
  @doc """
  Get model metadata.
  """
  @spec metadata(t()) :: map()
  def metadata(model), do: model.metadata

  ## Private Functions - Training

  defp count_statistics(training_data) do
    emission_counts = %{}
    transition_counts = %{}
    initial_counts = %{}
    tag_set = MapSet.new()
    vocabulary = MapSet.new()

    {emission_counts, transition_counts, initial_counts, tag_set, vocabulary} =
      Enum.reduce(
        training_data,
        {emission_counts, transition_counts, initial_counts, tag_set, vocabulary},
        fn {words, tags}, {e_counts, t_counts, i_counts, tags_acc, vocab_acc} ->
          # Update vocabulary and tag set
          tags_acc = Enum.reduce(tags, tags_acc, &MapSet.put(&2, &1))
          vocab_acc = Enum.reduce(words, vocab_acc, &MapSet.put(&2, String.downcase(&1)))

          # Count emissions
          e_counts =
            Enum.zip(words, tags)
            |> Enum.reduce(e_counts, fn {word, tag}, acc ->
              word_lower = String.downcase(word)
              update_nested_count(acc, word_lower, tag)
            end)

          # Count initial tags (first tag with special <START> context)
          i_counts =
            case tags do
              [first_tag | _] -> Map.update(i_counts, first_tag, 1, &(&1 + 1))
              _ -> i_counts
            end

          # Count transitions (trigram)
          t_counts =
            count_transitions(tags, t_counts)

          {e_counts, t_counts, i_counts, tags_acc, vocab_acc}
        end
      )

    {emission_counts, transition_counts, initial_counts, tag_set, vocabulary}
  end

  defp count_transitions(tags, transition_counts) do
    # Add START markers for sentence boundaries
    tags_with_start = [:START, :START | tags]

    tags_with_start
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.reduce(transition_counts, fn [tag1, tag2, tag3], acc ->
      context = {tag1, tag2}
      update_nested_count(acc, context, tag3)
    end)
  end

  defp update_nested_count(map, key1, key2) do
    Map.update(map, key1, %{key2 => 1}, fn inner_map ->
      Map.update(inner_map, key2, 1, &(&1 + 1))
    end)
  end

  defp normalize_emissions(emission_counts, tag_set, vocabulary, smoothing_k) do
    # P(word|tag) with add-k smoothing
    vocab_size = MapSet.size(vocabulary)

    Enum.reduce(emission_counts, %{}, fn {word, tag_counts}, acc ->
      word_probs =
        Enum.reduce(tag_set, %{}, fn tag, tag_acc ->
          count = Map.get(tag_counts, tag, 0)
          total = Enum.sum(Map.values(tag_counts)) + smoothing_k * vocab_size
          prob = (count + smoothing_k) / total
          Map.put(tag_acc, tag, prob)
        end)

      Map.put(acc, word, word_probs)
    end)
  end

  defp normalize_transitions(transition_counts, tag_set, smoothing_k) do
    # P(tag3|tag1, tag2) with add-k smoothing
    tag_list = MapSet.to_list(tag_set)
    num_tags = length(tag_list)

    # Generate all possible contexts (including START)
    contexts =
      for tag1 <- [:START | tag_list], tag2 <- [:START | tag_list] do
        {tag1, tag2}
      end

    Enum.reduce(contexts, %{}, fn context, acc ->
      tag_counts = Map.get(transition_counts, context, %{})
      total = Enum.sum(Map.values(tag_counts)) + smoothing_k * num_tags

      next_probs =
        Enum.reduce(tag_set, %{}, fn tag, tag_acc ->
          count = Map.get(tag_counts, tag, 0)
          prob = (count + smoothing_k) / total
          Map.put(tag_acc, tag, prob)
        end)

      Map.put(acc, context, next_probs)
    end)
  end

  defp normalize_initial(initial_counts, tag_set, smoothing_k) do
    # P(tag) at sentence start
    total = Enum.sum(Map.values(initial_counts)) + smoothing_k * MapSet.size(tag_set)

    Enum.reduce(tag_set, %{}, fn tag, acc ->
      count = Map.get(initial_counts, tag, 0)
      prob = (count + smoothing_k) / total
      Map.put(acc, tag, prob)
    end)
  end

  ## Private Functions - Viterbi Decoding

  defp viterbi(model, words) do
    tags = MapSet.to_list(model.tag_set)

    # Initialize: viterbi[tag] = log P(tag) + log P(word|tag)
    word0 = String.downcase(List.first(words))

    initial_probs =
      Enum.reduce(tags, %{}, fn tag, acc ->
        init_prob = Map.get(model.initial_probs, tag, model.smoothing_k)
        emit_prob = get_emission_prob(model, word0, tag)
        Map.put(acc, {0, tag}, :math.log(init_prob) + :math.log(emit_prob))
      end)

    # Backpointers for reconstruction
    backpointers = %{}

    # Forward pass
    {final_probs, backpointers} =
      words
      |> Enum.drop(1)
      |> Enum.with_index(1)
      |> Enum.reduce({initial_probs, backpointers}, fn {word, t}, {probs, bp} ->
        word_lower = String.downcase(word)

        {new_probs, new_bp} =
          Enum.reduce(tags, {%{}, bp}, fn curr_tag, {prob_acc, bp_acc} ->
            # Find best previous tag
            {best_score, best_prev} =
              tags
              |> Enum.map(fn prev_tag ->
                # Get prev-prev tag for trigram (if t >= 2)
                prev_prev_tag =
                  if t >= 2 do
                    # Find best tag at t-2
                    tags
                    |> Enum.max_by(fn pprev ->
                      Map.get(probs, {t - 2, pprev}, :neg_infinity)
                    end)
                  else
                    :START
                  end

                prev_score = Map.get(probs, {t - 1, prev_tag}, :neg_infinity)

                trans_prob =
                  get_transition_prob(model, prev_prev_tag, prev_tag, curr_tag)

                emit_prob = get_emission_prob(model, word_lower, curr_tag)

                score =
                  prev_score + :math.log(trans_prob) + :math.log(emit_prob)

                {score, prev_tag}
              end)
              |> Enum.max_by(fn {score, _} -> score end)

            prob_acc = Map.put(prob_acc, {t, curr_tag}, best_score)
            bp_acc = Map.put(bp_acc, {t, curr_tag}, best_prev)
            {prob_acc, bp_acc}
          end)

        {new_probs, new_bp}
      end)

    # Backtrack to find best path
    last_t = length(words) - 1

    best_last_tag =
      tags
      |> Enum.max_by(fn tag ->
        Map.get(final_probs, {last_t, tag}, :neg_infinity)
      end)

    # Reconstruct path
    reconstruct_path(backpointers, best_last_tag, last_t, [best_last_tag])
  end

  defp reconstruct_path(_bp, _tag, 0, path), do: Enum.reverse(path)

  defp reconstruct_path(bp, curr_tag, t, path) do
    prev_tag = Map.get(bp, {t, curr_tag})
    reconstruct_path(bp, prev_tag, t - 1, [prev_tag | path])
  end

  defp get_emission_prob(model, word, tag) do
    case Map.get(model.emission_probs, word) do
      nil ->
        # Unknown word: use smoothing
        model.smoothing_k

      tag_probs ->
        Map.get(tag_probs, tag, model.smoothing_k)
    end
  end

  defp get_transition_prob(model, tag1, tag2, tag3) do
    context = {tag1, tag2}

    case Map.get(model.transition_probs, context) do
      nil -> model.smoothing_k
      next_probs -> Map.get(next_probs, tag3, model.smoothing_k)
    end
  end
end
