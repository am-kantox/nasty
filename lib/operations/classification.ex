defmodule Nasty.Operations.Classification do
  @moduledoc """
  Behaviour for language-agnostic text classification.

  This behaviour defines the interface for training and using text classifiers
  that can work with any language.
  """

  alias Nasty.AST.{Classification, Document}

  @type options :: keyword()
  @type training_data :: [{text :: String.t() | Document.t(), category :: atom()}]
  @type model :: term()

  @doc """
  Trains a classifier on labeled training data.

  ## Parameters

    - `training_data` - List of {text, category} tuples
    - `opts` - Training options

  ## Returns

    - `{:ok, model}` - Trained model
    - `{:error, reason}` - Training error
  """
  @callback train(training_data :: training_data(), opts :: options()) ::
              {:ok, model()} | {:error, term()}

  @doc """
  Classifies text or document using trained model.

  ## Parameters

    - `model` - Trained classifier model
    - `input` - Text string or Document AST to classify
    - `opts` - Classification options

  ## Returns

    - `{:ok, classification}` - Classification result with confidence
    - `{:error, reason}` - Classification error
  """
  @callback classify(
              model :: model(),
              input :: String.t() | Document.t(),
              opts :: options()
            ) ::
              {:ok, Classification.t()} | {:error, term()}

  @doc """
  Returns supported classification algorithms.
  """
  @callback algorithms() :: [atom()]

  @optional_callbacks [algorithms: 0]
end
