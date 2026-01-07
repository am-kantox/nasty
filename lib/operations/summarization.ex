defmodule Nasty.Operations.Summarization do
  @moduledoc """
  Behaviour for language-agnostic text summarization.
  
  This behaviour defines the interface for extractive and abstractive summarization
  that can be implemented for any language.
  
  ## Example Implementation
  
      defmodule Nasty.Language.English.Summarizer do
        @behaviour Nasty.Operations.Summarization
        
        @impl true
        def summarize(document, opts) do
          # Language-specific summarization logic
          {:ok, sentences}
        end
        
        @impl true
        def methods, do: [:extractive, :mmr]
      end
  """

  alias Nasty.AST.{Document, Sentence}

  @typedoc """
  Summarization options.
  
  Common options:
  - `:ratio` - Compression ratio (0.0 to 1.0), default 0.3
  - `:max_sentences` - Maximum sentences in summary
  - `:min_sentence_length` - Minimum sentence length in tokens
  - `:method` - Selection method (`:greedy`, `:mmr`, `:abstractive`)
  - `:mmr_lambda` - MMR diversity parameter (0.0 to 1.0)
  """
  @type options :: keyword()

  @typedoc """
  Summarization methods supported.
  
  - `:extractive` - Extract sentences from document
  - `:mmr` - Maximal Marginal Relevance for diversity
  - `:abstractive` - Generate new summary text
  """
  @type method :: :extractive | :mmr | :abstractive

  @doc """
  Summarizes a document by selecting important content.
  
  ## Parameters
  
    - `document` - Document AST to summarize
    - `opts` - Summarization options
  
  ## Returns
  
    - `{:ok, sentences}` - List of selected sentences (extractive)
    - `{:ok, text}` - Generated summary text (abstractive)
    - `{:error, reason}` - Summarization error
  
  ## Examples
  
      iex> Summarizer.summarize(document, ratio: 0.3, method: :extractive)
      {:ok, [sentence1, sentence2]}
      
      iex> Summarizer.summarize(document, max_sentences: 5, method: :mmr)
      {:ok, [sentence1, sentence3, sentence5]}
  """
  @callback summarize(document :: Document.t(), opts :: options()) ::
              {:ok, [Sentence.t()] | String.t()} | {:error, term()}

  @doc """
  Returns the summarization methods supported by this implementation.
  
  ## Returns
  
    - List of supported method atoms
  
  ## Examples
  
      iex> Summarizer.methods()
      [:extractive, :mmr]
  """
  @callback methods() :: [method()]

  @optional_callbacks [methods: 0]
end
