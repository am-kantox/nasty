defmodule Nasty.Lexical.WordNet.Storage do
  @moduledoc """
  ETS-based in-memory storage for WordNet data with fast lookups.

  This module manages ETS tables for synsets, lemmas, and relations with multiple
  indexes for efficient queries. Uses lazy loading to minimize memory footprint
  and startup time.

  ## Storage Strategy

  ### ETS Tables

  1. `:wordnet_synsets_{lang}` - Main synset storage
     - Key: synset_id
     - Value: Synset struct
     - Type: :set

  2. `:wordnet_lemmas_{lang}` - Lemma storage
     - Key: {word, pos, synset_id}
     - Value: Lemma struct
     - Type: :bag (multiple lemmas per word)

  3. `:wordnet_word_index_{lang}` - Word to synsets index
     - Key: {word, pos}
     - Value: [synset_ids]
     - Type: :bag

  4. `:wordnet_relations_{lang}` - Relation storage
     - Key: {type, source_id}
     - Value: target_id
     - Type: :bag (multiple relations per source)

  5. `:wordnet_ili_index` - Interlingual index (shared across languages)
     - Key: ili_id
     - Value: {lang, synset_id}
     - Type: :bag

  ## Performance

  - Synset lookup by ID: O(1)
  - Lemmas by word: O(1)
  - Relations by source: O(1)
  - Memory: ~200MB for full OEWN, ~50MB for Spanish, ~40MB for Catalan

  ## Example

      # Initialize storage
      Storage.init(:en)

      # Store synsets
      Storage.put_synset(synset, :en)

      # Retrieve synsets
      synset = Storage.get_synset(synset_id, :en)
      synsets = Storage.get_synsets_for_word("dog", :noun, :en)
  """

  alias Nasty.Lexical.WordNet.{Lemma, Relation, Synset}

  require Logger

  @type language :: atom()
  @type table_name :: atom()

  @doc """
  Initializes ETS tables for a language.

  Creates all necessary tables if they don't exist. Safe to call multiple times.

  ## Examples

      iex> Storage.init(:en)
      :ok

      iex> Storage.init(:es)
      :ok
  """
  @spec init(language()) :: :ok
  def init(language) do
    # Create main tables
    create_table_if_not_exists(synsets_table(language), [:set, :public, :named_table])
    create_table_if_not_exists(lemmas_table(language), [:bag, :public, :named_table])
    create_table_if_not_exists(word_index_table(language), [:bag, :public, :named_table])
    create_table_if_not_exists(relations_table(language), [:bag, :public, :named_table])

    # Create shared ILI index (only once)
    create_table_if_not_exists(:wordnet_ili_index, [:bag, :public, :named_table])

    Logger.debug("Initialized WordNet storage for language: #{language}")
    :ok
  end

  @doc """
  Checks if a language's wordnet data is loaded.
  """
  @spec loaded?(language()) :: boolean()
  def loaded?(language) do
    case :ets.info(synsets_table(language)) do
      :undefined -> false
      info -> Keyword.get(info, :size, 0) > 0
    end
  end

  @doc """
  Clears all data for a language.

  Useful for reloading or testing.
  """
  @spec clear(language()) :: :ok
  def clear(language) do
    for table <- [
          synsets_table(language),
          lemmas_table(language),
          word_index_table(language),
          relations_table(language)
        ] do
      case :ets.info(table) do
        :undefined -> :ok
        _ -> :ets.delete_all_objects(table)
      end
    end

    :ok
  end

  @doc """
  Stores a synset in the database.

  Also updates ILI index if synset has an ILI.
  """
  @spec put_synset(Synset.t(), language()) :: :ok
  def put_synset(%Synset{} = synset, language) do
    :ets.insert(synsets_table(language), {synset.id, synset})

    # Update ILI index if present
    if synset.ili do
      :ets.insert(:wordnet_ili_index, {synset.ili, {language, synset.id}})
    end

    :ok
  end

  @doc """
  Retrieves a synset by ID.
  """
  @spec get_synset(String.t(), language()) :: Synset.t() | nil
  def get_synset(synset_id, language) do
    case :ets.lookup(synsets_table(language), synset_id) do
      [{^synset_id, synset}] -> synset
      [] -> nil
    end
  end

  @doc """
  Stores a lemma and updates word index.
  """
  @spec put_lemma(Lemma.t(), language()) :: :ok
  def put_lemma(%Lemma{} = lemma, language) do
    # Store lemma
    key = {lemma.word, lemma.pos, lemma.synset_id}
    :ets.insert(lemmas_table(language), {key, lemma})

    # Update word index
    index_key = {lemma.word, lemma.pos}
    :ets.insert(word_index_table(language), {index_key, lemma.synset_id})

    :ok
  end

  @doc """
  Gets all lemmas for a word (optionally filtered by POS).
  """
  @spec get_lemmas(String.t(), Synset.pos_tag() | nil, language()) :: [Lemma.t()]
  def get_lemmas(word, pos \\ nil, language) do
    normalized = Lemma.normalize(word)

    if pos do
      # Match pattern: {word, pos, _synset_id}
      pattern = {{normalized, pos, :_}, :"$1"}

      :ets.match(lemmas_table(language), pattern)
      |> Enum.map(fn [lemma] -> lemma end)
    else
      # Search across all POS tags
      for pos <- [:noun, :verb, :adj, :adv],
          [lemma] <- :ets.match(lemmas_table(language), {{normalized, pos, :_}, :"$1"}) do
        lemma
      end
    end
  end

  @doc """
  Gets all synset IDs for a word (fast index lookup).
  """
  @spec get_synset_ids_for_word(String.t(), Synset.pos_tag() | nil, language()) :: [String.t()]
  def get_synset_ids_for_word(word, pos \\ nil, language) do
    normalized = Lemma.normalize(word)

    if pos do
      key = {normalized, pos}

      :ets.lookup(word_index_table(language), key)
      |> Enum.map(fn {_key, synset_id} -> synset_id end)
      |> Enum.uniq()
    else
      # Search across all POS tags
      for pos <- [:noun, :verb, :adj, :adv],
          {_key, synset_id} <- :ets.lookup(word_index_table(language), {normalized, pos}) do
        synset_id
      end
      |> Enum.uniq()
    end
  end

  @doc """
  Gets all synsets for a word.

  Convenience function combining index lookup with synset retrieval.
  """
  @spec get_synsets_for_word(String.t(), Synset.pos_tag() | nil, language()) :: [Synset.t()]
  def get_synsets_for_word(word, pos \\ nil, language) do
    get_synset_ids_for_word(word, pos, language)
    |> Enum.map(&get_synset(&1, language))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Stores a relation between two synsets.
  """
  @spec put_relation(Relation.t(), language()) :: :ok
  def put_relation(%Relation{} = relation, language) do
    key = {relation.type, relation.source_id}
    :ets.insert(relations_table(language), {key, relation.target_id})
    :ok
  end

  @doc """
  Gets all target synset IDs for a given source and relation type.
  """
  @spec get_relations(String.t(), Relation.relation_type(), language()) :: [String.t()]
  def get_relations(source_id, rel_type, language) do
    key = {rel_type, source_id}

    :ets.lookup(relations_table(language), key)
    |> Enum.map(fn {_key, target_id} -> target_id end)
  end

  @doc """
  Gets all relations (of any type) from a source synset.
  """
  @spec get_all_relations(String.t(), language()) :: [{Relation.relation_type(), String.t()}]
  def get_all_relations(source_id, language) do
    # Note: This is less efficient as it needs to scan all relation types
    for rel_type <- relation_types(),
        target_id <- get_relations(source_id, rel_type, language) do
      {rel_type, target_id}
    end
  end

  @doc """
  Finds synsets by Interlingual Index (ILI) across languages.

  Returns synsets from specified language(s) that share the same ILI.
  """
  @spec get_by_ili(String.t(), language() | :all) :: [{language(), String.t()}] | [Synset.t()]
  def get_by_ili(ili_id, target_lang) when is_atom(target_lang) do
    results =
      :ets.lookup(:wordnet_ili_index, ili_id)
      |> Enum.map(fn {_ili, {lang, synset_id}} -> {lang, synset_id} end)

    case target_lang do
      :all ->
        # Return all languages
        Enum.map(results, fn {lang, synset_id} ->
          get_synset(synset_id, lang)
        end)
        |> Enum.reject(&is_nil/1)

      lang ->
        # Filter to specific language
        Enum.filter(results, fn {l, _} -> l == lang end)
        |> Enum.map(fn {_, synset_id} -> get_synset(synset_id, lang) end)
        |> Enum.reject(&is_nil/1)
    end
  end

  @doc """
  Returns statistics about loaded wordnet data.
  """
  @spec stats(language()) :: %{
          synsets: non_neg_integer(),
          lemmas: non_neg_integer(),
          relations: non_neg_integer()
        }
  def stats(language) do
    synsets = table_size(synsets_table(language))
    lemmas = table_size(lemmas_table(language))
    relations = table_size(relations_table(language))

    %{synsets: synsets, lemmas: lemmas, relations: relations}
  end

  # Private helpers

  defp synsets_table(lang), do: :"wordnet_synsets_#{lang}"
  defp lemmas_table(lang), do: :"wordnet_lemmas_#{lang}"
  defp word_index_table(lang), do: :"wordnet_word_index_#{lang}"
  defp relations_table(lang), do: :"wordnet_relations_#{lang}"

  defp create_table_if_not_exists(name, options) do
    case :ets.info(name) do
      :undefined ->
        :ets.new(name, options)
        :ok

      _ ->
        :ok
    end
  end

  defp table_size(table_name) do
    case :ets.info(table_name) do
      :undefined -> 0
      info -> Keyword.get(info, :size, 0)
    end
  end

  defp relation_types do
    [
      :hypernym,
      :hyponym,
      :instance_hypernym,
      :instance_hyponym,
      :meronym,
      :holonym,
      :member_meronym,
      :member_holonym,
      :substance_meronym,
      :substance_holonym,
      :similar_to,
      :antonym,
      :also_see,
      :entailment,
      :cause,
      :verb_group,
      :attribute,
      :pertainym,
      :derivationally_related
    ]
  end
end
