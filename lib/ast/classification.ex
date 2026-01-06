defmodule Nasty.AST.Classification do
  @moduledoc """
  Classification result representing the predicted class for a document.

  Used by text classification systems to represent predictions with
  confidence scores and probability distributions.
  """

  alias Nasty.AST.Node

  @type t :: %__MODULE__{
          class: atom(),
          confidence: float(),
          features: map(),
          probabilities: %{atom() => float()},
          language: Node.language()
        }

  @enforce_keys [:class, :confidence, :language]
  defstruct [
    :class,
    :confidence,
    :features,
    :probabilities,
    :language
  ]

  @doc """
  Creates a new classification result.

  ## Examples

      iex> classification = Nasty.AST.Classification.new(:spam, 0.95, :en)
      iex> classification.class
      :spam
      iex> classification.confidence
      0.95
  """
  @spec new(atom(), float(), Node.language(), keyword()) :: t()
  def new(class, confidence, language, opts \\ []) do
    %__MODULE__{
      class: class,
      confidence: confidence,
      language: language,
      features: Keyword.get(opts, :features),
      probabilities: Keyword.get(opts, :probabilities, %{})
    }
  end

  @doc """
  Sorts classifications by confidence (highest first).

  ## Examples

      iex> classifications = [
      ...>   Nasty.AST.Classification.new(:low, 0.3, :en),
      ...>   Nasty.AST.Classification.new(:high, 0.9, :en),
      ...>   Nasty.AST.Classification.new(:mid, 0.6, :en)
      ...> ]
      iex> sorted = Nasty.AST.Classification.sort_by_confidence(classifications)
      iex> Enum.map(sorted, & &1.class)
      [:high, :mid, :low]
  """
  @spec sort_by_confidence([t()]) :: [t()]
  def sort_by_confidence(classifications) do
    Enum.sort_by(classifications, & &1.confidence, :desc)
  end
end

defmodule Nasty.AST.ClassificationModel do
  @moduledoc """
  Classification model containing learned parameters for prediction.

  Stores the trained model parameters including class priors,
  feature probabilities, and vocabulary for making predictions
  on new documents.
  """

  @typedoc """
  Classification algorithm type.
  """
  @type algorithm :: :naive_bayes | :svm | :logistic_regression

  @type t :: %__MODULE__{
          algorithm: algorithm(),
          classes: [atom()],
          class_priors: %{atom() => float()},
          feature_probs: %{atom() => %{any() => float()}},
          vocabulary: MapSet.t(),
          metadata: map()
        }

  @enforce_keys [:algorithm, :classes]
  defstruct [
    :algorithm,
    :classes,
    class_priors: %{},
    feature_probs: %{},
    vocabulary: MapSet.new(),
    metadata: %{}
  ]

  @doc """
  Creates a new classification model.

  ## Examples

      iex> model = Nasty.AST.ClassificationModel.new(:naive_bayes, [:spam, :ham])
      iex> model.algorithm
      :naive_bayes
      iex> model.classes
      [:spam, :ham]
  """
  @spec new(algorithm(), [atom()], keyword()) :: t()
  def new(algorithm, classes, opts \\ []) do
    %__MODULE__{
      algorithm: algorithm,
      classes: classes,
      class_priors: Keyword.get(opts, :class_priors, %{}),
      feature_probs: Keyword.get(opts, :feature_probs, %{}),
      vocabulary: Keyword.get(opts, :vocabulary, MapSet.new()),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Checks if the model has been trained (has learned parameters).

  ## Examples

      iex> model = Nasty.AST.ClassificationModel.new(:naive_bayes, [:spam, :ham])
      iex> Nasty.AST.ClassificationModel.trained?(model)
      false
  """
  @spec trained?(t()) :: boolean()
  def trained?(%__MODULE__{class_priors: priors}) when map_size(priors) > 0, do: true
  def trained?(_), do: false
end
