defmodule Nasty.Language.Spanish.TextClassifier do
  @moduledoc """
  Classifies Spanish text into categories using Naive Bayes.

  Supports multi-class and multi-label classification with
  TF-IDF feature extraction and Naive Bayes classification.

  ## Features

  - Bag-of-words with Spanish stop words
  - TF-IDF weighting
  - N-gram features (unigrams, bigrams)
  - Training on labeled examples

  ## Example

      iex> classifier = TextClassifier.train([
      ...>   {"Este producto es excelente", :positive},
      ...>   {"No me gusta nada", :negative}
      ...> ])
      iex> TextClassifier.classify("Me encanta este producto", classifier)
      {:ok, :positive, 0.87}
  """

  alias Nasty.Operations.Classification.NaiveBayes

  @doc """
  Trains a Spanish text classifier on labeled examples.

  ## Parameters

  - `examples` - List of `{text, label}` tuples
  - `opts` - Options:
    - `:ngrams` - N-gram size (default: 1)
    - `:min_freq` - Minimum term frequency (default: 1)

  ## Returns

  A trained classifier model.
  """
  @spec train([{String.t(), atom()}], keyword()) :: map()
  def train(examples, opts \\ []) do
    config = spanish_config()
    NaiveBayes.train(examples, Keyword.merge([config: config], opts))
  end

  @doc """
  Classifies a Spanish text using a trained model.

  ## Parameters

  - `text` - Text to classify
  - `model` - Trained classifier from `train/2`

  ## Returns

  `{:ok, label, confidence}` or `{:error, reason}`
  """
  @spec classify(String.t(), map()) :: {:ok, atom(), float()} | {:error, String.t()}
  def classify(text, model) do
    # Extract features from text
    features = extract_features(text)

    # Predict using NaiveBayes
    case NaiveBayes.predict(model, features, :es) do
      [] -> {:error, "No predictions available"}
      [top | _rest] -> {:ok, top.class, top.confidence}
    end
  end

  # Extract features from raw text
  defp extract_features(text) do
    config = spanish_config()

    # Tokenize and normalize
    tokens =
      text
      |> String.downcase()
      |> String.split(config.tokenizer)
      |> Enum.reject(&(&1 == "" or MapSet.member?(config.stop_words, &1)))

    # Create bag-of-words feature map
    tokens
    |> Enum.frequencies()
  end

  # Spanish-specific classification configuration
  defp spanish_config do
    %{
      # Spanish stop words (same as summarizer)
      stop_words:
        MapSet.new([
          "el",
          "la",
          "los",
          "las",
          "un",
          "una",
          "unos",
          "unas",
          "de",
          "a",
          "en",
          "por",
          "para",
          "con",
          "sin",
          "sobre",
          "entre",
          "desde",
          "hasta",
          "y",
          "e",
          "o",
          "u",
          "pero",
          "mas",
          "sino",
          "ni",
          "que",
          "yo",
          "tú",
          "él",
          "ella",
          "nosotros",
          "vosotros",
          "ellos",
          "me",
          "te",
          "lo",
          "la",
          "se",
          "nos",
          "os",
          "les",
          "ser",
          "estar",
          "haber",
          "tener",
          "muy",
          "más",
          "menos",
          "también",
          "tampoco",
          "sí",
          "no"
        ]),
      # Tokenization pattern (split on whitespace and punctuation)
      tokenizer: ~r/[\s\p{P}]+/u,
      # Case sensitivity
      case_sensitive: false,
      # Feature extraction
      features: %{
        ngrams: true,
        tfidf: true,
        pos_tags: false,
        # Not yet implemented for Spanish
        entities: false
        # Not yet implemented for Spanish
      }
    }
  end
end
