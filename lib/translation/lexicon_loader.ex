defmodule Nasty.Translation.LexiconLoader do
  @moduledoc """
  Loads and caches bilingual lexicons for translation.

  Uses ETS (Erlang Term Storage) for fast in-memory lookups of word translations.
  Lexicons are loaded from .exs files in priv/translation/lexicons/.

  ## Supported Language Pairs

  - en_es (English → Spanish)
  - es_en (Spanish → English)
  - en_ca (English → Catalan)  
  - ca_en (Catalan → English)
  - es_ca (Spanish → Catalan)
  - ca_es (Catalan → Spanish)

  ## Usage

      # Start the loader (usually done by application supervisor)
      LexiconLoader.start_link()

      # Lookup a word
      LexiconLoader.lookup("cat", :en, :es)
      # => {:ok, %{translations: ["gato", "gata"], gender: :m}}

      # Check if lexicon is loaded
      LexiconLoader.loaded?(:en, :es)
      # => true

  """

  use GenServer
  require Logger

  @table_name :translation_lexicons
  @lexicon_pairs [:en_es, :es_en, :en_ca, :ca_en, :es_ca, :ca_es]

  ## Client API

  @doc """
  Starts the Lexicon Loader GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Looks up a word translation in the lexicon.

  Returns `{:ok, translation}` if found, `:not_found` otherwise.

  ## Examples

      iex> LexiconLoader.lookup("cat", :en, :es)
      {:ok, %{translations: ["gato", "gata"], gender: :m}}

      iex> LexiconLoader.lookup("gato", :es, :en)
      {:ok, %{base: "cat", type: :noun}}

      iex> LexiconLoader.lookup("nonexistent", :en, :es)
      :not_found

  """
  @spec lookup(String.t(), atom(), atom()) :: {:ok, term()} | :not_found
  def lookup(word, source_lang, target_lang) do
    pair_key = make_pair_key(source_lang, target_lang)
    lookup_key = {pair_key, String.downcase(word)}

    case :ets.lookup(@table_name, lookup_key) do
      [{^lookup_key, translation}] -> {:ok, translation}
      [] -> :not_found
    end
  end

  @doc """
  Checks if a lexicon for a language pair is loaded.

  ## Examples

      iex> LexiconLoader.loaded?(:en, :es)
      true

      iex> LexiconLoader.loaded?(:en, :fr)
      false

  """
  @spec loaded?(atom(), atom()) :: boolean()
  def loaded?(source_lang, target_lang) do
    pair_key = make_pair_key(source_lang, target_lang)
    GenServer.call(__MODULE__, {:loaded?, pair_key})
  end

  @doc """
  Reloads all lexicons from disk.

  Useful during development or if lexicons are updated.
  """
  @spec reload() :: :ok
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc """
  Returns statistics about loaded lexicons.

  ## Examples

      iex> LexiconLoader.stats()
      %{
        en_es: %{entries: 308, loaded: true},
        es_en: %{entries: 352, loaded: true},
        ...
      }

  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for fast lookups
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])

    # Load all lexicons
    loaded_pairs = load_all_lexicons()

    Logger.info("Lexicon Loader initialized with #{map_size(loaded_pairs)} language pairs")

    {:ok, %{loaded: loaded_pairs}}
  end

  @impl true
  def handle_call({:loaded?, pair_key}, _from, state) do
    {:reply, Map.has_key?(state.loaded, pair_key), state}
  end

  @impl true
  def handle_call(:reload, _from, _state) do
    # Clear ETS table
    :ets.delete_all_objects(@table_name)

    # Reload lexicons
    loaded_pairs = load_all_lexicons()

    Logger.info("Reloaded #{map_size(loaded_pairs)} language pairs")

    {:reply, :ok, %{loaded: loaded_pairs}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.new(state.loaded, fn {pair_key, count} ->
        {pair_key, %{entries: count, loaded: true}}
      end)

    {:reply, stats, state}
  end

  ## Private Functions

  defp load_all_lexicons do
    @lexicon_pairs
    |> Enum.map(&load_lexicon/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp load_lexicon(pair_key) do
    path = lexicon_path(pair_key)

    case File.exists?(path) do
      true ->
        case load_lexicon_file(path, pair_key) do
          {:ok, count} ->
            Logger.debug("Loaded lexicon #{pair_key}: #{count} entries")
            {pair_key, count}

          {:error, reason} ->
            Logger.warning("Failed to load lexicon #{pair_key}: #{inspect(reason)}")
            nil
        end

      false ->
        Logger.debug("Lexicon file not found: #{path}")
        nil
    end
  end

  defp load_lexicon_file(path, pair_key) do
    # Evaluate the .exs file to get the map
    {lexicon, _} = Code.eval_file(path)

    # Insert all entries into ETS
    count =
      Enum.reduce(lexicon, 0, fn {word, translation}, acc ->
        key = {pair_key, String.downcase(word)}
        :ets.insert(@table_name, {key, translation})
        acc + 1
      end)

    {:ok, count}
  rescue
    error ->
      {:error, error}
  end

  defp lexicon_path(pair_key) do
    filename = "#{pair_key}.exs"
    Path.join([Application.app_dir(:nasty, "priv"), "translation", "lexicons", filename])
  end

  defp make_pair_key(source_lang, target_lang) do
    String.to_atom("#{source_lang}_#{target_lang}")
  end
end
