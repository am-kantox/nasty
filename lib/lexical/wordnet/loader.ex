defmodule Nasty.Lexical.WordNet.Loader do
  @moduledoc """
  Loads WordNet data from WN-LMF (Lexical Markup Framework) JSON files.

  Parses Open English WordNet and Open Multilingual WordNet JSON files
  and populates ETS storage with synsets, lemmas, and relations.

  ## WN-LMF Format

  The WN-LMF format has two main sections:

  1. **Lexical Entries** - Words with their senses
  2. **Synsets** - Synonym sets with definitions, examples, and relations

  ## Example

      # Load English WordNet
      Loader.load_from_file("priv/wordnet/oewn-2025.json", :en)

      # Load Spanish WordNet
      Loader.load_from_file("priv/wordnet/omw-es.json", :es)

  ## Performance

  - Parsing: ~1-2 seconds for full OEWN (120K synsets)
  - ETS loading: ~1 second
  - Total: 2-3 seconds per language
  """

  alias Nasty.Lexical.WordNet.{Lemma, Relation, Storage, Synset}

  require Logger

  @type load_result :: {:ok, %{synsets: integer(), lemmas: integer(), relations: integer()}}
  @type load_error :: {:error, term()}

  @doc """
  Loads WordNet data from a JSON file.

  ## Parameters

  - `file_path` - Path to WN-LMF JSON file
  - `language` - Language code (:en, :es, :ca, etc.)
  - `opts` - Options
    - `:clear` - Clear existing data before loading (default: false)
    - `:validate` - Validate data integrity (default: true)

  ## Returns

  - `{:ok, stats}` with counts of loaded items
  - `{:error, reason}` on failure
  """
  @spec load_from_file(String.t(), atom(), keyword()) :: load_result() | load_error()
  def load_from_file(file_path, language, opts \\ []) do
    Logger.info("Loading WordNet data from #{file_path} for language #{language}")

    with {:ok, json_data} <- read_json_file(file_path),
         {:ok, parsed_data} <- parse_wn_lmf(json_data, language),
         :ok <- maybe_clear(language, opts),
         :ok <- Storage.init(language),
         {:ok, stats} <- load_into_storage(parsed_data, language, opts) do
      Logger.info("Successfully loaded WordNet for #{language}: #{inspect(stats)}")
      {:ok, stats}
    else
      {:error, reason} = error ->
        Logger.error("Failed to load WordNet: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Loads WordNet data from a JSON string.

  Useful for testing or loading from external sources.
  """
  @spec load_from_json(String.t(), atom(), keyword()) :: load_result() | load_error()
  def load_from_json(json_string, language, opts \\ []) do
    with {:ok, json_data} <- decode_json(json_string),
         {:ok, parsed_data} <- parse_wn_lmf(json_data, language),
         :ok <- maybe_clear(language, opts),
         :ok <- Storage.init(language),
         do: load_into_storage(parsed_data, language, opts)
  end

  # Private functions

  defp read_json_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> decode_json(content)
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp decode_json(json_string) do
    data = :json.decode(json_string)
    {:ok, data}
  rescue
    e -> {:error, {:json_decode_error, e}}
  end

  defp maybe_clear(language, opts) do
    if Keyword.get(opts, :clear, false) do
      Storage.clear(language)
    end

    :ok
  end

  defp parse_wn_lmf(json_data, language) do
    synsets = parse_synsets(json_data, language)
    lemmas = parse_lemmas(json_data, language)
    relations = parse_relations(json_data, language)

    {:ok, %{synsets: synsets, lemmas: lemmas, relations: relations}}
  rescue
    e ->
      {:error, {:parse_error, e}}
  end

  defp parse_synsets(json_data, language) do
    synsets_data = Map.get(json_data, "synsets", [])

    Enum.map(synsets_data, fn synset_json ->
      parse_synset(synset_json, language)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_synset(synset_json, language) do
    id = Map.get(synset_json, "id")
    pos = parse_pos(Map.get(synset_json, "partOfSpeech"))
    definition = Map.get(synset_json, "definition", "")
    examples = Map.get(synset_json, "examples", [])
    members = Map.get(synset_json, "members", [])
    ili = Map.get(synset_json, "ili")

    if id && pos && definition do
      {:ok, synset} =
        Synset.new(id, pos, definition, language,
          examples: examples,
          lemmas: members,
          ili: ili
        )

      synset
    else
      Logger.warning("Skipping invalid synset: #{inspect(synset_json)}")
      nil
    end
  end

  defp parse_lemmas(json_data, language) do
    # Extract lemmas from lexicalEntries section
    entries = Map.get(json_data, "lexicalEntries", [])

    Enum.flat_map(entries, fn entry ->
      parse_entry_lemmas(entry, language)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_entry_lemmas(entry, language) do
    lemma_data = Map.get(entry, "lemma", %{})
    word = Map.get(lemma_data, "writtenForm")
    pos = parse_pos(Map.get(lemma_data, "partOfSpeech"))

    senses = Map.get(entry, "senses", [])

    Enum.map(senses, fn sense ->
      parse_sense_lemma(word, pos, sense, language)
    end)
  end

  defp parse_sense_lemma(word, pos, sense, language) do
    sense_id = Map.get(sense, "id")
    synset_id = Map.get(sense, "synset")

    if word && pos && sense_id && synset_id do
      {:ok, lemma} = Lemma.new(word, pos, synset_id, sense_id, language)
      lemma
    else
      nil
    end
  end

  defp parse_relations(json_data, language) do
    synsets_data = Map.get(json_data, "synsets", [])

    Enum.flat_map(synsets_data, fn synset_json ->
      source_id = Map.get(synset_json, "id")
      relations_data = Map.get(synset_json, "relations", [])

      Enum.map(relations_data, fn rel_json ->
        parse_relation(source_id, rel_json, language)
      end)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_relation(source_id, rel_json, _language) do
    rel_type = parse_relation_type(Map.get(rel_json, "relType"))
    target_id = Map.get(rel_json, "target")

    if rel_type && target_id do
      {:ok, relation} = Relation.new(rel_type, source_id, target_id)
      relation
    else
      nil
    end
  end

  defp load_into_storage(parsed_data, language, opts) do
    validate = Keyword.get(opts, :validate, true)

    # Load synsets
    synset_count =
      Enum.reduce(parsed_data.synsets, 0, fn synset, acc ->
        if validate && !valid_synset?(synset) do
          Logger.warning("Invalid synset skipped: #{synset.id}")
          acc
        else
          Storage.put_synset(synset, language)
          acc + 1
        end
      end)

    # Load lemmas
    lemma_count =
      Enum.reduce(parsed_data.lemmas, 0, fn lemma, acc ->
        if validate && !valid_lemma?(lemma) do
          Logger.warning("Invalid lemma skipped: #{lemma.word}")
          acc
        else
          Storage.put_lemma(lemma, language)
          acc + 1
        end
      end)

    # Load relations
    relation_count =
      Enum.reduce(parsed_data.relations, 0, fn relation, acc ->
        Storage.put_relation(relation, language)
        acc + 1
      end)

    stats = %{synsets: synset_count, lemmas: lemma_count, relations: relation_count}
    {:ok, stats}
  end

  # POS tag conversion from WN-LMF to internal format
  defp parse_pos(pos_string) when is_binary(pos_string) do
    case String.downcase(pos_string) do
      "n" -> :noun
      "noun" -> :noun
      "v" -> :verb
      "verb" -> :verb
      "a" -> :adj
      "adj" -> :adj
      "adjective" -> :adj
      "r" -> :adv
      "adv" -> :adv
      "adverb" -> :adv
      _ -> nil
    end
  end

  defp parse_pos(_), do: nil

  # Relation type conversion from WN-LMF to internal format
  defp parse_relation_type(rel_string) when is_binary(rel_string) do
    # Convert from various formats (camelCase, snake_case, etc.)
    normalized =
      rel_string
      |> String.replace(~r/([a-z])([A-Z])/, "\\1_\\2")
      |> String.downcase()
      |> String.to_atom()

    if Relation.valid_type?(normalized) do
      normalized
    else
      # Try common aliases
      case normalized do
        :hyper -> :hypernym
        :hypo -> :hyponym
        :mero -> :meronym
        :holo -> :holonym
        :similar -> :similar_to
        _ -> nil
      end
    end
  end

  defp parse_relation_type(_), do: nil

  # Validation helpers

  defp valid_synset?(%Synset{id: id, pos: pos, definition: def}) do
    is_binary(id) && String.length(id) > 0 &&
      Synset.valid_pos?(pos) &&
      is_binary(def) && String.length(def) > 0
  end

  defp valid_lemma?(%Lemma{word: word, pos: pos, synset_id: sid}) do
    is_binary(word) && String.length(word) > 0 &&
      Synset.valid_pos?(pos) &&
      is_binary(sid) && String.length(sid) > 0
  end
end
