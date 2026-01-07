defmodule Nasty.Semantic.EntityRecognition do
  @moduledoc """
  Behaviour for language-agnostic named entity recognition (NER).

  This behaviour defines the interface for identifying and classifying named entities
  in text, regardless of the source language.
  """

  alias Nasty.AST.{Document, Semantic, Sentence, Token}

  @type options :: keyword()
  @type entity_types :: [:person | :organization | :location | :date | :money | :percent | :misc]

  @doc """
  Recognizes named entities in a document.

  ## Parameters

    - `document` - Document AST to process
    - `opts` - Recognition options
      - `:types` - Specific entity types to recognize (default: all)
      - `:confidence_threshold` - Minimum confidence (default: 0.5)

  ## Returns

    - `{:ok, entities}` - List of recognized entities
    - `{:error, reason}` - Recognition error
  """
  @callback recognize_document(document :: Document.t(), opts :: options()) ::
              {:ok, [Semantic.Entity.t()]} | {:error, term()}

  @doc """
  Recognizes named entities in a sentence.

  ## Parameters

    - `sentence` - Sentence AST to process
    - `opts` - Recognition options

  ## Returns

    - `{:ok, entities}` - List of recognized entities
    - `{:error, reason}` - Recognition error
  """
  @callback recognize_sentence(sentence :: Sentence.t(), opts :: options()) ::
              {:ok, [Semantic.Entity.t()]} | {:error, term()}

  @doc """
  Recognizes named entities from token sequence.

  ## Parameters

    - `tokens` - List of tokens to analyze
    - `opts` - Recognition options

  ## Returns

    - `{:ok, entities}` - List of recognized entities
    - `{:error, reason}` - Recognition error
  """
  @callback recognize(tokens :: [Token.t()], opts :: options()) ::
              {:ok, [Semantic.Entity.t()]} | {:error, term()}

  @doc """
  Returns entity types supported by this implementation.
  """
  @callback supported_types() :: entity_types()

  @optional_callbacks [supported_types: 0]
end
