defmodule Nasty.Language.Resources.LexiconLoader do
  @moduledoc """
  Loads and caches lexicon files from the priv/languages directory.

  Lexicons are loaded at compile time and cached as module attributes
  for fast runtime access.

  ## File Format

  Lexicon files should be Elixir term files (.exs) that evaluate to a list of strings:

      # Example: priv/languages/english/lexicons/determiners.exs
      ~w(the a an this that these those)

  ## Usage

      # Get a lexicon
      determiners = LexiconLoader.load(:en, :determiners)
      
      # Check if word is in lexicon
      LexiconLoader.in_lexicon?(:en, :determiners, "the")  # => true
  """

  @priv_dir :code.priv_dir(:nasty) |> to_string()

  @doc """
  Loads a lexicon for the given language and name.

  ## Parameters

  - `language` - Language code (`:en`, `:es`, `:ca`, etc.)
  - `lexicon_name` - Name of the lexicon (`:determiners`, `:verbs`, etc.)

  ## Returns

  List of words in the lexicon, or raises if file not found.

  ## Examples

      iex> LexiconLoader.load(:en, :determiners)
      ["the", "a", "an", ...]
  """
  @spec load(atom(), atom()) :: [String.t()]
  def load(language, lexicon_name) do
    path = lexicon_path(language, lexicon_name)

    case File.exists?(path) do
      true ->
        {result, _} = Code.eval_file(path)
        result

      false ->
        raise "Lexicon file not found: #{path}"
    end
  end

  @doc """
  Checks if a word is in the specified lexicon.

  ## Parameters

  - `language` - Language code
  - `lexicon_name` - Name of the lexicon
  - `word` - Word to check (case-sensitive)

  ## Returns

  `true` if word is in lexicon, `false` otherwise.
  """
  @spec in_lexicon?(atom(), atom(), String.t()) :: boolean()
  def in_lexicon?(language, lexicon_name, word) do
    word in load(language, lexicon_name)
  end

  @doc """
  Returns the full path to a lexicon file.

  ## Parameters

  - `language` - Language code
  - `lexicon_name` - Name of the lexicon

  ## Returns

  Absolute path to the lexicon file.
  """
  @spec lexicon_path(atom(), atom()) :: String.t()
  def lexicon_path(language, lexicon_name) do
    Path.join([
      @priv_dir,
      "languages",
      to_string(language),
      "lexicons",
      "#{lexicon_name}.exs"
    ])
  end

  @doc """
  Lists all available lexicons for a language.

  ## Parameters

  - `language` - Language code

  ## Returns

  List of lexicon names (as atoms) available for the language.
  """
  @spec list_lexicons(atom()) :: [atom()]
  def list_lexicons(language) do
    lexicons_dir =
      Path.join([
        @priv_dir,
        "languages",
        to_string(language),
        "lexicons"
      ])

    case File.ls(lexicons_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".exs"))
        |> Enum.map(fn file ->
          file
          |> String.replace_suffix(".exs", "")
          |> String.to_atom()
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Preloads all lexicons for a language at compile time.

  This macro can be used in a module to preload lexicons as module attributes:

      defmodule MyModule do
        require Nasty.Language.Resources.LexiconLoader
        
        LexiconLoader.preload_lexicons(:en, [:determiners, :verbs])
        
        @determiners LexiconLoader.load(:en, :determiners)
        @verbs LexiconLoader.load(:en, :verbs)
      end
  """
  defmacro preload_lexicons(language, lexicon_names) do
    # credo:disable-for-lines:5
    quote bind_quoted: [language: language, lexicon_names: lexicon_names] do
      for lexicon_name <- lexicon_names do
        Nasty.Language.Resources.LexiconLoader.load(language, lexicon_name)
      end
    end
  end
end
