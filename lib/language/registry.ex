defmodule Nasty.Language.Registry do
  @moduledoc """
  Registry for managing natural language implementations.

  The registry maps language codes to their implementation modules
  and provides language detection and validation utilities.
  """

  use Agent

  alias Nasty.Language.Behaviour

  @typedoc """
  Language code (ISO 639-1).
  """
  @type language_code :: atom()

  @typedoc """
  Module implementing Nasty.Language.Behaviour.
  """
  @type language_module :: module()

  ## Client API

  @doc """
  Starts the language registry.

  Automatically called when the application starts.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Registers a language implementation module.

  Validates that the module implements the Language.Behaviour correctly
  before registration.

  ## Examples

      iex> Nasty.Language.Registry.register(Nasty.Language.English)
      :ok
      
      iex> Nasty.Language.Registry.register(InvalidModule)
      {:error, "Module does not implement Nasty.Language.Behaviour"}
  """
  @spec register(language_module()) :: :ok | {:error, String.t()}
  def register(module) do
    Behaviour.validate_implementation!(module)
    language_code = module.language_code()

    Agent.update(__MODULE__, fn registry ->
      Map.put(registry, language_code, module)
    end)

    :ok
  rescue
    e in ArgumentError ->
      {:error, Exception.message(e)}
  end

  @doc """
  Gets the implementation module for a language code.

  ## Examples

      iex> Nasty.Language.Registry.get(:en)
      {:ok, Nasty.Language.English}
      
      iex> Nasty.Language.Registry.get(:fr)
      {:error, :language_not_found}
  """
  @spec get(language_code()) :: {:ok, language_module()} | {:error, :language_not_found}
  def get(language_code) do
    case Agent.get(__MODULE__, fn registry -> Map.get(registry, language_code) end) do
      nil -> {:error, :language_not_found}
      module -> {:ok, module}
    end
  end

  @doc """
  Gets the implementation module for a language code, raising on error.

  ## Examples

      iex> Nasty.Language.Registry.get!(:en)
      Nasty.Language.English
      
      iex> Nasty.Language.Registry.get!(:fr)
      ** (RuntimeError) Language not found: :fr
  """
  @spec get!(language_code()) :: language_module() | no_return()
  def get!(language_code) do
    case get(language_code) do
      {:ok, module} -> module
      {:error, :language_not_found} -> raise "Language not found: #{inspect(language_code)}"
    end
  end

  @doc """
  Returns all registered language codes.

  ## Examples

      iex> Nasty.Language.Registry.registered_languages()
      [:en, :es, :ca]
  """
  @spec registered_languages() :: [language_code()]
  def registered_languages do
    Agent.get(__MODULE__, fn registry -> Map.keys(registry) end)
  end

  @doc """
  Checks if a language is registered.

  ## Examples

      iex> Nasty.Language.Registry.registered?(:en)
      true
      
      iex> Nasty.Language.Registry.registered?(:fr)
      false
  """
  @spec registered?(language_code()) :: boolean()
  def registered?(language_code) do
    Agent.get(__MODULE__, fn registry -> Map.has_key?(registry, language_code) end)
  end

  @doc """
  Unregisters a language implementation.

  ## Examples

      iex> Nasty.Language.Registry.unregister(:en)
      :ok
  """
  @spec unregister(language_code()) :: :ok
  def unregister(language_code) do
    Agent.update(__MODULE__, fn registry ->
      Map.delete(registry, language_code)
    end)

    :ok
  end

  @doc """
  Clears all registered languages.

  Primarily for testing purposes.

  ## Examples

      iex> Nasty.Language.Registry.clear()
      :ok
  """
  @spec clear() :: :ok
  def clear do
    Agent.update(__MODULE__, fn _registry -> %{} end)
    :ok
  end

  @doc """
  Detects the language of the given text.

  Uses heuristics:
  - Character set analysis (Latin, Cyrillic, Arabic, etc.)
  - Common word frequency analysis
  - Statistical language models

  Returns the most likely language code from registered languages.
  If no registered language matches, returns {:error, :no_match}.

  ## Examples

      iex> Nasty.Language.Registry.detect_language("Hello world")
      {:ok, :en}
      
      iex> Nasty.Language.Registry.detect_language("你好世界")
      {:error, :no_match}
  """
  @spec detect_language(String.t()) :: {:ok, language_code()} | {:error, term()}
  def detect_language(text) when is_binary(text) and byte_size(text) > 0 do
    registered = registered_languages()

    if Enum.empty?(registered) do
      {:error, :no_languages_registered}
    else
      scores =
        Enum.map(registered, fn lang_code ->
          {lang_code, score_language(text, lang_code)}
        end)

      {best_lang, best_score} = Enum.max_by(scores, fn {_lang, score} -> score end)

      if best_score > 0.0 do
        {:ok, best_lang}
      else
        {:error, :no_match}
      end
    end
  end

  def detect_language(_text), do: {:error, :invalid_text}

  # Private helper to score how likely text is in a given language
  defp score_language(text, language_code) do
    normalized_text = String.downcase(text)
    words = String.split(normalized_text, ~r/\W+/, trim: true)

    char_score = character_set_score(text, language_code)
    word_score = common_word_score(words, language_code)

    # Weighted average: character analysis (30%), word frequency (70%)
    char_score * 0.3 + word_score * 0.7
  end

  # Scores based on character distribution
  defp character_set_score(text, :en) do
    # English uses Latin alphabet, common letters
    latin_count = count_chars(text, ~r/[a-zA-Z]/)
    total_alpha = String.replace(text, ~r/[^\p{L}]/u, "") |> String.length()

    if total_alpha > 0, do: latin_count / total_alpha, else: 0.0
  end

  defp character_set_score(text, :es) do
    # Spanish uses Latin with ñ, accented vowels
    latin_count = count_chars(text, ~r/[a-zA-ZñÑáéíóúÁÉÍÓÚüÜ]/)
    total_alpha = String.replace(text, ~r/[^\p{L}]/u, "") |> String.length()

    if total_alpha > 0, do: latin_count / total_alpha, else: 0.0
  end

  defp character_set_score(text, :ca) do
    # Catalan uses Latin with special characters
    latin_count = count_chars(text, ~r/[a-zA-ZçÇàèéíòóúÀÈÉÍÒÓÚïÏüÜ]/)
    total_alpha = String.replace(text, ~r/[^\p{L}]/u, "") |> String.length()

    if total_alpha > 0, do: latin_count / total_alpha, else: 0.0
  end

  defp character_set_score(_text, _lang), do: 0.5

  # Scores based on common word frequency
  defp common_word_score(words, :en) do
    common_english =
      MapSet.new([
        "the",
        "be",
        "to",
        "of",
        "and",
        "a",
        "in",
        "that",
        "have",
        "i",
        "it",
        "for",
        "not",
        "on",
        "with",
        "he",
        "as",
        "you",
        "do",
        "at",
        "this",
        "but",
        "his",
        "by",
        "from",
        "they",
        "we",
        "say",
        "her",
        "she",
        "or",
        "an",
        "will",
        "my",
        "one",
        "all",
        "would",
        "there",
        "their",
        "what",
        "so",
        "up",
        "out",
        "if",
        "about",
        "who",
        "get",
        "which",
        "go",
        "me",
        "when",
        "make",
        "can",
        "like",
        "time",
        "no",
        "just",
        "him",
        "know",
        "take",
        "people",
        "into",
        "year",
        "your",
        "good",
        "some",
        "could",
        "them",
        "see",
        "other",
        "than",
        "then",
        "now",
        "look",
        "only",
        "come",
        "its",
        "over",
        "think",
        "also",
        "back",
        "after",
        "use",
        "two",
        "how",
        "our",
        "work",
        "first",
        "well",
        "way",
        "even",
        "new",
        "want",
        "because",
        "any",
        "these",
        "give",
        "day",
        "most",
        "us",
        "is",
        "was",
        "are",
        "been",
        "has",
        "had",
        "were",
        "said",
        "did",
        "having"
      ])

    score_against_common_words(words, common_english)
  end

  defp common_word_score(words, :es) do
    common_spanish =
      MapSet.new([
        "el",
        "la",
        "de",
        "que",
        "y",
        "a",
        "en",
        "un",
        "ser",
        "se",
        "no",
        "haber",
        "por",
        "con",
        "su",
        "para",
        "como",
        "estar",
        "tener",
        "le",
        "lo",
        "todo",
        "pero",
        "más",
        "hacer",
        "o",
        "poder",
        "decir",
        "este",
        "ir",
        "otro",
        "ese",
        "la",
        "si",
        "me",
        "ya",
        "ver",
        "porque",
        "dar",
        "cuando",
        "él",
        "muy",
        "sin",
        "vez",
        "mucho",
        "saber",
        "qué",
        "sobre",
        "mi",
        "alguno",
        "mismo",
        "yo",
        "también",
        "hasta",
        "año",
        "dos",
        "querer",
        "entre",
        "así",
        "primero",
        "desde",
        "grande",
        "eso",
        "ni",
        "nos",
        "llegar",
        "pasar",
        "tiempo",
        "ella",
        "sí",
        "día",
        "uno",
        "bien",
        "poco",
        "deber",
        "entonces",
        "poner",
        "cosa",
        "tanto",
        "hombre",
        "parecer",
        "nuestro",
        "tan",
        "donde",
        "ahora",
        "parte",
        "después",
        "vida",
        "quedar",
        "siempre",
        "creer",
        "hablar",
        "llevar",
        "dejar",
        "nada",
        "cada",
        "seguir",
        "menos",
        "nuevo",
        "encontrar",
        "es",
        "son",
        "fue",
        "era",
        "han",
        "había",
        "sido",
        "estaba",
        "tiene",
        "hay"
      ])

    score_against_common_words(words, common_spanish)
  end

  defp common_word_score(words, :ca) do
    common_catalan =
      MapSet.new([
        "el",
        "la",
        "de",
        "i",
        "a",
        "que",
        "en",
        "un",
        "és",
        "per",
        "una",
        "amb",
        "es",
        "dels",
        "les",
        "dels",
        "al",
        "als",
        "més",
        "són",
        "com",
        "ha",
        "o",
        "però",
        "aquesta",
        "aquest",
        "també",
        "tot",
        "hi",
        "no",
        "quan",
        "sobre",
        "altres",
        "seva",
        "seu",
        "fer",
        "entre",
        "des",
        "està",
        "dos",
        "tres",
        "poden",
        "molt",
        "altres",
        "sense",
        "fins",
        "només",
        "aquests",
        "seu",
        "sia",
        "han",
        "altre",
        "mateix",
        "anys",
        "primer",
        "any",
        "aquest",
        "ser",
        "estat",
        "tots",
        "seves",
        "seus",
        "aquestes",
        "cada",
        "durant",
        "després",
        "seva",
        "tal",
        "nou",
        "gran",
        "pot",
        "si",
        "fet",
        "mes",
        "on",
        "així",
        "cas",
        "això",
        "haver",
        "tenir",
        "era",
        "van",
        "estava",
        "eren",
        "has",
        "havia",
        "hem",
        "heu",
        "han",
        "havia"
      ])

    score_against_common_words(words, common_catalan)
  end

  defp common_word_score(_words, _lang), do: 0.0

  defp score_against_common_words(words, common_set) do
    if Enum.empty?(words) do
      0.0
    else
      matches = Enum.count(words, &MapSet.member?(common_set, &1))
      matches / length(words)
    end
  end

  defp count_chars(text, regex) do
    text
    |> String.graphemes()
    |> Enum.count(&String.match?(&1, regex))
  end

  @doc """
  Returns metadata for all registered languages.

  ## Examples

      iex> Nasty.Language.Registry.all_metadata()
      %{
        en: %{version: "1.0.0", features: [...]},
        es: %{version: "1.0.0", features: [...]}
      }
  """
  @spec all_metadata() :: %{language_code() => map()}
  def all_metadata do
    Agent.get(__MODULE__, fn registry ->
      Map.new(registry, fn {code, module} ->
        metadata =
          if function_exported?(module, :metadata, 0) do
            module.metadata()
          else
            %{}
          end

        {code, metadata}
      end)
    end)
  end
end
