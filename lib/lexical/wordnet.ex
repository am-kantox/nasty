defmodule Nasty.Lexical.WordNet do
  @moduledoc """
  Main API for accessing WordNet lexical database.

  Provides high-level functions for querying synsets, lemmas, relations,
  and semantic similarity. Implements lazy loading to load WordNet data
  only when first accessed.

  ## Quick Start

      # Get synsets for a word
      synsets = WordNet.synsets("dog", :noun)

      # Get definition
      definition = WordNet.definition(synset_id)

      # Get synonyms
      synonyms = WordNet.synonyms("big")

      # Get hypernyms (more general concepts)
      hypernyms = WordNet.hypernyms(synset_id)

  ## Languages

  Currently supports:
  - `:en` - English (Open English WordNet)
  - `:es` - Spanish (Open Multilingual WordNet)
  - `:ca` - Catalan (Open Multilingual WordNet)

  ## Data Loading

  WordNet data is loaded lazily on first access. To pre-load:

      WordNet.ensure_loaded(:en)
      WordNet.ensure_loaded(:es)

  ## Example

      # Find synsets for "dog"
      iex> WordNet.synsets("dog", :noun, :en)
      [
        %Synset{id: "oewn-02084071-n", definition: "a member of the genus Canis", ...},
        %Synset{id: "oewn-10144073-n", definition: "informal term for a man", ...}
      ]

      # Get definition
      iex> WordNet.definition("oewn-02084071-n", :en)
      "a member of the genus Canis"

      # Get hypernyms
      iex> WordNet.hypernyms("oewn-02084071-n", :en)
      ["oewn-02083346-n"]  # canine

      # Get synonyms via synsets
      iex> WordNet.synonyms("big", :adj, :en)
      ["large", "big"]
  """

  alias Nasty.Lexical.WordNet.{Lemma, Loader, Relation, Storage, Synset}

  require Logger

  @default_language :en
  @wordnet_data_dir "priv/wordnet"

  # Public API - Synset Operations

  @doc """
  Gets all synsets for a word with optional POS filter.

  ## Parameters

  - `word` - Word to look up
  - `pos` - Part of speech filter (:noun, :verb, :adj, :adv) or nil for all
  - `language` - Language code (default: :en)

  ## Examples

      iex> WordNet.synsets("dog")
      [%Synset{...}, ...]

      iex> WordNet.synsets("run", :verb)
      [%Synset{...}, ...]
  """
  @spec synsets(String.t(), Synset.pos_tag() | nil, atom()) :: [Synset.t()]
  def synsets(word, pos \\ nil, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_synsets_for_word(word, pos, language)
  end

  @doc """
  Gets a synset by its ID.

  ## Examples

      iex> WordNet.synset("oewn-02084071-n", :en)
      %Synset{id: "oewn-02084071-n", ...}
  """
  @spec synset(String.t(), atom()) :: Synset.t() | nil
  def synset(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_synset(synset_id, language)
  end

  @doc """
  Gets the definition of a synset.

  ## Examples

      iex> WordNet.definition("oewn-02084071-n", :en)
      "a member of the genus Canis"
  """
  @spec definition(String.t(), atom()) :: String.t() | nil
  def definition(synset_id, language \\ @default_language) do
    case synset(synset_id, language) do
      %Synset{definition: def} -> def
      nil -> nil
    end
  end

  @doc """
  Gets usage examples for a synset.

  ## Examples

      iex> WordNet.examples("oewn-02084071-n", :en)
      ["the dog barked all night"]
  """
  @spec examples(String.t(), atom()) :: [String.t()]
  def examples(synset_id, language \\ @default_language) do
    case synset(synset_id, language) do
      %Synset{examples: examples} -> examples
      nil -> []
    end
  end

  # Lemma Operations

  @doc """
  Gets all lemmas (word senses) for a word.

  ## Examples

      iex> WordNet.lemmas("dog")
      [%Lemma{word: "dog", synset_id: "oewn-02084071-n", ...}, ...]
  """
  @spec lemmas(String.t(), Synset.pos_tag() | nil, atom()) :: [Lemma.t()]
  def lemmas(word, pos \\ nil, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_lemmas(word, pos, language)
  end

  # Relation Operations

  @doc """
  Gets hypernyms (more general concepts) for a synset.

  ## Examples

      iex> WordNet.hypernyms("oewn-02084071-n", :en)  # dog
      ["oewn-02083346-n"]  # canine
  """
  @spec hypernyms(String.t(), atom()) :: [String.t()]
  def hypernyms(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_relations(synset_id, :hypernym, language)
  end

  @doc """
  Gets hyponyms (more specific concepts) for a synset.

  ## Examples

      iex> WordNet.hyponyms("oewn-02083346-n", :en)  # canine
      ["oewn-02084071-n", ...]  # dog, wolf, fox, ...
  """
  @spec hyponyms(String.t(), atom()) :: [String.t()]
  def hyponyms(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_relations(synset_id, :hyponym, language)
  end

  @doc """
  Gets meronyms (part-of relations) for a synset.

  ## Examples

      iex> WordNet.meronyms("oewn-02958343-n", :en)  # car
      ["oewn-03903868-n", ...]  # wheel, door, engine, ...
  """
  @spec meronyms(String.t(), atom()) :: [String.t()]
  def meronyms(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_relations(synset_id, :meronym, language)
  end

  @doc """
  Gets holonyms (whole-of relations) for a synset.

  ## Examples

      iex> WordNet.holonyms("oewn-03903868-n", :en)  # wheel
      ["oewn-02958343-n", ...]  # car, bicycle, ...
  """
  @spec holonyms(String.t(), atom()) :: [String.t()]
  def holonyms(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_relations(synset_id, :holonym, language)
  end

  @doc """
  Gets antonyms (opposites) for a synset.

  ## Examples

      iex> WordNet.antonyms("oewn-01386883-a", :en)  # hot
      ["oewn-01387319-a"]  # cold
  """
  @spec antonyms(String.t(), atom()) :: [String.t()]
  def antonyms(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_relations(synset_id, :antonym, language)
  end

  @doc """
  Gets similar synsets.

  ## Examples

      iex> WordNet.similar("oewn-01386883-a", :en)  # hot
      ["oewn-01391351-a", ...]  # warm, ...
  """
  @spec similar(String.t(), atom()) :: [String.t()]
  def similar(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_relations(synset_id, :similar_to, language)
  end

  @doc """
  Gets all relations from a synset.

  Returns list of `{relation_type, target_synset_id}` tuples.
  """
  @spec all_relations(String.t(), atom()) :: [{Relation.relation_type(), String.t()}]
  def all_relations(synset_id, language \\ @default_language) do
    ensure_loaded(language)
    Storage.get_all_relations(synset_id, language)
  end

  # Synonym/Antonym via Synsets

  @doc """
  Gets synonyms for a word by finding all words in same synsets.

  ## Examples

      iex> WordNet.synonyms("big")
      ["large", "big"]
  """
  @spec synonyms(String.t(), Synset.pos_tag() | nil, atom()) :: [String.t()]
  def synonyms(word, pos \\ nil, language \\ @default_language) do
    synsets(word, pos, language)
    |> Enum.flat_map(& &1.lemmas)
    |> Enum.uniq()
  end

  # Semantic Path Operations

  @doc """
  Finds common hypernyms (shared ancestors) between two synsets.

  Returns list of synset IDs that are hypernyms of both input synsets.
  """
  @spec common_hypernyms(String.t(), String.t(), atom()) :: [String.t()]
  def common_hypernyms(synset1_id, synset2_id, language \\ @default_language) do
    hypernyms1 = collect_all_hypernyms(synset1_id, language)
    hypernyms2 = collect_all_hypernyms(synset2_id, language)

    MapSet.intersection(MapSet.new(hypernyms1), MapSet.new(hypernyms2))
    |> MapSet.to_list()
  end

  @doc """
  Finds the shortest path between two synsets in the hypernym hierarchy.

  Returns the path length (number of edges), or nil if no path exists.
  """
  @spec shortest_path(String.t(), String.t(), atom()) :: non_neg_integer() | nil
  def shortest_path(synset1_id, synset2_id, language \\ @default_language) do
    if synset1_id == synset2_id do
      0
    else
      bfs_shortest_path(synset1_id, synset2_id, language)
    end
  end

  # Cross-lingual Operations

  @doc """
  Finds synsets in target language via Interlingual Index.

  ## Examples

      iex> spanish_dog = WordNet.synsets("perro", :noun, :es) |> hd()
      iex> WordNet.from_ili(spanish_dog.ili, :en)
      [%Synset{id: "oewn-02084071-n", lemmas: ["dog", ...]}]
  """
  @spec from_ili(String.t(), atom()) :: [Synset.t()]
  def from_ili(ili_id, target_language) do
    Storage.get_by_ili(ili_id, target_language)
  end

  # Data Loading

  @doc """
  Ensures WordNet data for a language is loaded.

  Automatically called by query functions, but can be called explicitly
  to pre-load data.
  """
  @spec ensure_loaded(atom()) :: :ok | {:error, term()}
  def ensure_loaded(language) do
    if Storage.loaded?(language) do
      :ok
    else
      load_language(language)
    end
  end

  @doc """
  Checks if WordNet data is loaded for a language.
  """
  @spec loaded?(atom()) :: boolean()
  def loaded?(language) do
    Storage.loaded?(language)
  end

  @doc """
  Returns statistics about loaded WordNet data.

  ## Examples

      iex> WordNet.stats(:en)
      %{synsets: 120532, lemmas: 155287, relations: 207016}
  """
  @spec stats(atom()) :: map()
  def stats(language) do
    if loaded?(language) do
      Storage.stats(language)
    else
      %{synsets: 0, lemmas: 0, relations: 0}
    end
  end

  # Private Helpers

  defp load_language(language) do
    file_path = wordnet_file_path(language)

    case File.exists?(file_path) do
      true ->
        Logger.info("Loading WordNet data for language: #{language}")

        case Loader.load_from_file(file_path, language) do
          {:ok, _stats} ->
            :ok

          {:error, reason} = error ->
            Logger.error("Failed to load WordNet for #{language}: #{inspect(reason)}")
            error
        end

      false ->
        Logger.warning(
          "WordNet data file not found for #{language}: #{file_path}. " <>
            "Run 'mix nasty.wordnet.download --language #{language}' to download."
        )

        {:error, :wordnet_not_found}
    end
  end

  defp wordnet_file_path(language) do
    filename =
      case language do
        :en -> "oewn-2025.json"
        :es -> "omw-es.json"
        :ca -> "omw-ca.json"
        _ -> "omw-#{language}.json"
      end

    Path.join([@wordnet_data_dir, filename])
  end

  defp collect_all_hypernyms(synset_id, language) do
    collect_all_hypernyms(synset_id, language, MapSet.new(), [synset_id])
  end

  defp collect_all_hypernyms(_synset_id, _language, visited, []) do
    MapSet.to_list(visited)
  end

  defp collect_all_hypernyms(synset_id, language, visited, [current | queue]) do
    if MapSet.member?(visited, current) do
      collect_all_hypernyms(synset_id, language, visited, queue)
    else
      parents = hypernyms(current, language)
      new_visited = MapSet.put(visited, current)
      new_queue = queue ++ parents

      collect_all_hypernyms(synset_id, language, new_visited, new_queue)
    end
  end

  defp bfs_shortest_path(start_id, target_id, language) do
    bfs_shortest_path(
      target_id,
      language,
      :queue.from_list([{start_id, 0}]),
      MapSet.new([start_id])
    )
  end

  defp bfs_shortest_path(_target_id, _language, queue, _visited) when queue == {[], []} do
    nil
  end

  defp bfs_shortest_path(target_id, language, queue, visited) do
    {{:value, {current_id, distance}}, new_queue} = :queue.out(queue)

    if current_id == target_id do
      distance
    else
      # Explore neighbors (hypernyms and hyponyms for bidirectional search)
      neighbors =
        (hypernyms(current_id, language) ++ hyponyms(current_id, language))
        |> Enum.reject(&MapSet.member?(visited, &1))

      new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))

      new_queue_with_neighbors =
        Enum.reduce(neighbors, new_queue, fn neighbor, q ->
          :queue.in({neighbor, distance + 1}, q)
        end)

      bfs_shortest_path(target_id, language, new_queue_with_neighbors, new_visited)
    end
  end
end
