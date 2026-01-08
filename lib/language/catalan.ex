defmodule Nasty.Language.Catalan do
  @moduledoc """
  Catalan (Català) language implementation for Nasty.

  Provides complete NLP pipeline for Catalan text:
  - Tokenization with Catalan-specific features (interpunct, contractions)
  - POS tagging using Universal Dependencies tagset
  - Morphological analysis (lemmatization, features)
  - Syntactic parsing (phrases, sentences, clauses)
  - Dependency extraction (Universal Dependencies)
  - Named entity recognition
  - Text summarization

  ## Catalan-Specific Features

  - **Interpunct (l·l)**: Handled in tokenization (e.g., "col·laborar")
  - **Apostrophe contractions**: l', d', s', n', m', t'
  - **Article contractions**: del (de + el), al (a + el), pel (per + el)
  - **Pro-drop**: Subject pronouns often omitted
  - **Post-nominal adjectives**: "casa blanca" (white house)
  - **Clitic pronouns**: em, et, es, ens, us

  ## Usage

      iex> alias Nasty.Language.Catalan
      iex> {:ok, tokens} = Catalan.tokenize("El gat dorm al sofà.")
      iex> {:ok, tagged} = Catalan.tag_pos(tokens)
      iex> {:ok, document} = Catalan.parse(tagged)

  ## Language Code

  Catalan uses the ISO 639-1 code `:ca`.
  """

  @behaviour Nasty.Language.Behaviour

  alias Nasty.Language.Catalan

  @doc """
  Returns the ISO 639-1 language code for Catalan.

  ## Examples

      iex> Nasty.Language.Catalan.language_code()
      :ca
  """
  @impl true
  @spec language_code() :: :ca
  def language_code, do: :ca

  @doc """
  Tokenizes Catalan text into tokens with position tracking.

  Handles Catalan-specific features:
  - Interpunct (l·l) kept as single token
  - Apostrophe contractions (l'home → ["l'", "home"])
  - Article contractions (del → ["de", "el"])
  - Catalan diacritics (à, è, é, í, ï, ò, ó, ú, ü, ç)

  ## Options

  - `:preserve_contractions` - Keep contractions intact (default: false)

  ## Examples

      iex> Catalan.tokenize("L'home col·labora.")
      {:ok, [%Token{text: "L'"}, %Token{text: "home"}, %Token{text: "col·labora"}, %Token{text: "."}]}
  """
  @impl true
  defdelegate tokenize(text, opts \\ []), to: Catalan.Tokenizer

  @doc """
  Assigns part-of-speech tags to Catalan tokens using Universal Dependencies tagset.

  Supports multiple tagging models:
  - `:rule` - Rule-based tagging (default, ~85% accuracy)
  - `:hmm` - Hidden Markov Model (future, ~95% accuracy)
  - `:neural` - Neural network (future, ~97% accuracy)

  ## Options

  - `:model` - Tagging model to use (default: `:rule`)

  ## Examples

      iex> {:ok, tokens} = Catalan.tokenize("El gat dorm.")
      iex> Catalan.tag_pos(tokens)
      {:ok, [%Token{text: "El", pos_tag: :det}, %Token{text: "gat", pos_tag: :noun}, ...]}
  """
  @impl true
  defdelegate tag_pos(tokens, opts \\ []), to: Catalan.POSTagger

  @doc """
  Parses tagged Catalan tokens into a complete Document AST.

  The parsing pipeline:
  1. Morphological analysis (lemmatization, features)
  2. Phrase parsing (NP, VP, PP, AdjP, AdvP)
  3. Sentence parsing (clauses, coordination, subordination)
  4. Document construction (paragraphs, sentences)

  ## Options

  - `:dependencies` - Extract dependency relations (default: false)
  - `:entities` - Recognize named entities (default: false)
  - `:semantic_roles` - Extract semantic roles (default: false)

  ## Examples

      iex> {:ok, tokens} = Catalan.tokenize("La Maria treballa a Barcelona.")
      iex> {:ok, tagged} = Catalan.tag_pos(tokens)
      iex> Catalan.parse(tagged)
      {:ok, %Document{paragraphs: [%Paragraph{sentences: [...]}]}}
  """
  @impl true
  def parse(tokens, opts \\ []) do
    # Pipeline: morphology → phrase parsing → sentence parsing → document
    with {:ok, tokens_with_morphology} <- Catalan.Morphology.analyze(tokens),
         {:ok, document} <- Catalan.Parser.parse(tokens_with_morphology, opts) do
      {:ok, document}
    end
  end

  @doc """
  Renders a Catalan AST node back to natural language text.

  Handles:
  - Subject-verb agreement
  - Gender/number agreement (adjectives, articles)
  - Catalan word order (post-nominal adjectives)
  - Proper punctuation and capitalization

  ## Examples

      iex> document = %Document{...}
      iex> Catalan.render(document)
      {:ok, "El gat dorm al sofà."}
  """
  @impl true
  defdelegate render(ast, opts \\ []), to: Catalan.Renderer

  @doc """
  Returns metadata about the Catalan language implementation.

  ## Examples

      iex> Catalan.metadata()
      %{
        name: "Catalan",
        native_name: "Català",
        iso_639_1: "ca",
        family: "Romance",
        speakers: "~10 million"
      }
  """
  @impl true
  def metadata do
    %{
      name: "Catalan",
      native_name: "Català",
      iso_639_1: "ca",
      iso_639_3: "cat",
      family: "Romance",
      branch: "Western Romance",
      speakers: "~10 million",
      regions: ["Catalonia", "Valencia", "Balearic Islands", "Andorra", "Roussillon"],
      writing_system: "Latin alphabet",
      features: [
        "Pro-drop language",
        "Post-nominal adjectives",
        "Clitic pronouns",
        "Interpunct (l·l)",
        "Three verb conjugations"
      ]
    }
  end

  @doc """
  Extracts named entities from Catalan text.

  Recognizes:
  - Person names (with Catalan naming patterns)
  - Organizations
  - Locations (Catalan place names)
  - Dates

  ## Examples

      iex> {:ok, document} = Catalan.parse(tokens)
      iex> Catalan.extract_entities(document)
      [%Entity{type: :person, text: "Josep Maria"}, ...]
  """
  @spec extract_entities(Nasty.AST.Document.t()) :: [Nasty.AST.Entity.t()]
  def extract_entities(%Nasty.AST.Document{} = document) do
    # Extract tokens from document
    tokens =
      document.paragraphs
      |> Enum.flat_map(& &1.sentences)
      |> Enum.flat_map(&Nasty.Utils.Query.extract_tokens/1)

    Catalan.EntityRecognizer.recognize(tokens)
  end

  @doc """
  Summarizes Catalan text using extractive summarization.

  ## Options

  - `:ratio` - Compression ratio (0.0-1.0)
  - `:max_sentences` - Maximum sentences in summary
  - `:method` - `:textrank` or `:mmr` (default: `:textrank`)

  ## Examples

      iex> {:ok, document} = Catalan.parse(tokens)
      iex> Catalan.summarize(document, ratio: 0.3)
      "El gat dorm. La casa és gran."
  """
  @spec summarize(Nasty.AST.Document.t(), keyword()) :: String.t()
  def summarize(%Nasty.AST.Document{} = document, opts \\ []) do
    Catalan.Summarizer.summarize(document, opts)
  end
end
