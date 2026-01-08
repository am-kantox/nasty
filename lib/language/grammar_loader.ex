defmodule Nasty.Language.GrammarLoader do
  @moduledoc """
  Loads and caches grammar rules from external resource files.

  Supports loading grammar rules from `.exs` files in `priv/languages/{lang}/grammars/`
  and provides caching for efficient rule lookup.

  ## Grammar File Format

  Grammar files should return an Elixir map with rule definitions:

      # priv/languages/english/grammars/phrase_rules.exs
      %{
        noun_phrases: [
          %{
            pattern: [:det, :adj, :noun],
            description: "Basic NP with determiner and adjective",
            examples: ["the big dog", "a red car"]
          }
        ],
        verb_phrases: [
          %{
            pattern: [:verb, :np],
            description: "Transitive verb with object",
            examples: ["eat food", "read books"]
          }
        ]
      }

  ## Usage

      # Load default grammar
      {:ok, rules} = GrammarLoader.load(:en, :phrase_rules)

      # Load custom variant
      {:ok, rules} = GrammarLoader.load(:en, :phrase_rules, variant: :formal)

      # Load from custom file
      {:ok, rules} = GrammarLoader.load_file("path/to/custom_grammar.exs")

  ## Caching

  Grammar rules are cached in ETS after first load for performance.
  Use `clear_cache/0` or `clear_cache/2` to invalidate cache.
  """

  require Logger

  @type language :: atom()
  @type rule_type :: atom()
  @type variant :: atom()
  @type rules :: map()
  @type load_result :: {:ok, rules()} | {:error, term()}

  # ETS table for caching grammar rules
  @cache_table :grammar_rules_cache

  @doc """
  Starts the grammar loader and initializes the cache.

  Called automatically by the application supervisor.
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    case :ets.info(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table])
        Logger.debug("Grammar cache initialized")

      _ ->
        :ok
    end

    {:ok, self()}
  end

  @doc """
  Loads grammar rules for a language and rule type.

  ## Parameters

  - `language` - Language code (`:en`, `:es`, `:ca`)
  - `rule_type` - Type of rules (`:phrase_rules`, `:dependency_rules`, etc.)
  - `opts` - Options:
    - `:variant` - Grammar variant to load (default: `:default`)
    - `:force_reload` - Skip cache and reload from disk (default: `false`)

  ## Returns

  - `{:ok, rules}` - Map of grammar rules
  - `{:error, reason}` - Error loading rules

  ## Examples

      iex> GrammarLoader.load(:en, :phrase_rules)
      {:ok, %{noun_phrases: [...], verb_phrases: [...]}}

      iex> GrammarLoader.load(:en, :phrase_rules, variant: :formal)
      {:ok, %{noun_phrases: [...]}}
  """
  @spec load(language(), rule_type(), keyword()) :: load_result()
  def load(language, rule_type, opts \\ []) do
    variant = Keyword.get(opts, :variant, :default)
    force_reload = Keyword.get(opts, :force_reload, false)

    cache_key = {language, rule_type, variant}

    case get_from_cache(cache_key) do
      {:ok, rules} when not force_reload ->
        {:ok, rules}

      _ ->
        load_and_cache(language, rule_type, variant)
    end
  end

  @doc """
  Loads grammar rules from a custom file path.

  ## Parameters

  - `file_path` - Absolute or relative path to `.exs` grammar file
  - `opts` - Options:
    - `:cache_key` - Custom cache key (default: file path)

  ## Returns

  - `{:ok, rules}` - Map of grammar rules
  - `{:error, reason}` - Error loading file

  ## Examples

      iex> GrammarLoader.load_file("my_grammar.exs")
      {:ok, %{...}}
  """
  @spec load_file(String.t(), keyword()) :: load_result()
  def load_file(file_path, opts \\ []) do
    cache_key = Keyword.get(opts, :cache_key, {:file, file_path})

    case get_from_cache(cache_key) do
      {:ok, rules} ->
        {:ok, rules}

      _ ->
        case read_grammar_file(file_path) do
          {:ok, rules} ->
            validate_rules(rules)
            put_in_cache(cache_key, rules)
            {:ok, rules}

          error ->
            error
        end
    end
  end

  @doc """
  Validates grammar rules structure.

  Returns `:ok` if valid, raises if invalid.

  ## Examples

      iex> GrammarLoader.validate_rules(%{noun_phrases: []})
      :ok
  """
  @spec validate_rules(rules()) :: :ok
  def validate_rules(rules) when is_map(rules) do
    # Basic validation - rules should be a map
    # Individual parsers can do more specific validation
    :ok
  end

  def validate_rules(_), do: raise(ArgumentError, "Grammar rules must be a map")

  @doc """
  Clears the entire grammar cache.

  ## Examples

      iex> GrammarLoader.clear_cache()
      :ok
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    case :ets.info(@cache_table) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(@cache_table)
    end

    Logger.debug("Grammar cache cleared")
    :ok
  end

  @doc """
  Clears cache for specific language and rule type.

  ## Examples

      iex> GrammarLoader.clear_cache(:en, :phrase_rules)
      :ok
  """
  @spec clear_cache(language(), rule_type(), variant()) :: :ok
  def clear_cache(language, rule_type, variant \\ :default) do
    cache_key = {language, rule_type, variant}

    case :ets.info(@cache_table) do
      :undefined -> :ok
      _ -> :ets.delete(@cache_table, cache_key)
    end

    :ok
  end

  # Private functions

  defp load_and_cache(language, rule_type, variant) do
    file_path = grammar_file_path(language, rule_type, variant)

    case read_grammar_file(file_path) do
      {:ok, rules} ->
        validate_rules(rules)
        cache_key = {language, rule_type, variant}
        put_in_cache(cache_key, rules)
        Logger.debug("Loaded grammar: #{inspect(cache_key)}")
        {:ok, rules}

      {:error, :enoent} ->
        # File doesn't exist, return empty rules
        Logger.debug("Grammar file not found: #{file_path}, using empty rules")
        {:ok, %{}}

      {:error, reason} = error ->
        Logger.error("Failed to load grammar from #{file_path}: #{inspect(reason)}")
        error
    end
  end

  defp grammar_file_path(language, rule_type, :default) do
    Path.join([
      :code.priv_dir(:nasty),
      "languages",
      to_string(language),
      "grammars",
      "#{rule_type}.exs"
    ])
  end

  defp grammar_file_path(language, rule_type, variant) do
    Path.join([
      :code.priv_dir(:nasty),
      "languages",
      to_string(language),
      "variants",
      "#{variant}",
      "#{rule_type}.exs"
    ])
  end

  defp read_grammar_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Evaluate the Elixir code and return the result
        {result, _} = Code.eval_string(content, [], file: file_path)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      {:error, {:eval_error, e}}
  end

  defp get_from_cache(key) do
    ensure_cache_exists()

    case :ets.lookup(@cache_table, key) do
      [{^key, rules}] -> {:ok, rules}
      [] -> :error
    end
  end

  defp put_in_cache(key, rules) do
    ensure_cache_exists()
    :ets.insert(@cache_table, {key, rules})
    :ok
  end

  defp ensure_cache_exists do
    case :ets.info(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table])
        :ok

      _ ->
        :ok
    end
  end
end
