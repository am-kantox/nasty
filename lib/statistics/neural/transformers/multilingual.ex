defmodule Nasty.Statistics.Neural.Transformers.Multilingual do
  @moduledoc """
  Multilingual support utilities for transformer models.

  Provides helpers for:
  - Cross-lingual model selection (XLM-RoBERTa, mBERT)
  - Language detection and routing
  - Cross-lingual transfer learning
  - Zero-shot cross-lingual prediction

  ## Supported Languages

  XLM-RoBERTa supports 100 languages including:
  - European: English, Spanish, Catalan, French, German, Italian, Portuguese, etc.
  - Asian: Chinese, Japanese, Korean, Arabic, Hindi, Thai, Vietnamese, etc.
  - Others: Russian, Turkish, Hebrew, Indonesian, etc.

  ## Examples

      # Detect language and use appropriate model
      {:ok, language} = Multilingual.detect_language(text)
      {:ok, model} = Multilingual.model_for_language(language)

      # Cross-lingual transfer: train on English, predict on Spanish
      {:ok, model} = Multilingual.train_cross_lingual(:en, training_data, :es)

      # Zero-shot cross-lingual: use English model for Spanish
      {:ok, tagged} = Multilingual.predict_cross_lingual(model, spanish_tokens)
  """

  alias Nasty.AST.Token
  alias Nasty.Statistics.Neural.Transformers.{FineTuner, Loader, TokenClassifier}

  require Logger

  # Multilingual model configurations
  @multilingual_models %{
    xlm_roberta_base: %{
      languages: 100,
      best_for: [:cross_lingual, :zero_shot, :multilingual],
      accuracy: :high
    },
    mbert: %{
      languages: 104,
      best_for: [:multilingual, :translation],
      accuracy: :medium
    },
    xlm_mlm_100: %{
      languages: 100,
      best_for: [:cross_lingual],
      accuracy: :medium
    }
  }

  @doc """
  Gets the best multilingual model for a specific language.

  ## Examples

      {:ok, model_name} = Multilingual.model_for_language(:es)
      # => {:ok, :xlm_roberta_base}

      {:ok, model_name} = Multilingual.model_for_language(:zh)
      # => {:ok, :xlm_roberta_base}
  """
  @spec model_for_language(atom(), keyword()) :: {:ok, atom()} | {:error, term()}
  def model_for_language(language, opts \\ []) do
    task = Keyword.get(opts, :task, :general)

    model =
      cond do
        task in [:cross_lingual, :zero_shot] ->
          :xlm_roberta_base

        language in [:en, :de, :fr, :it, :es, :pt] ->
          # For well-supported languages, prefer XLM-RoBERTa
          :xlm_roberta_base

        true ->
          # For other languages, use XLM-RoBERTa
          :xlm_roberta_base
      end

    {:ok, model}
  end

  @doc """
  Trains a model on one language for use on another (cross-lingual transfer).

  This is useful when you have training data in one language but want to
  apply the model to another language.

  ## Options

    * `:source_language` - Language of training data (e.g., :en)
    * `:target_languages` - Languages to apply model to (e.g., [:es, :ca])
    * `:task` - Task type (:pos_tagging, :ner, etc.)
    * All FineTuner options

  ## Examples

      # Train English POS tagger, use for Spanish/Catalan
      {:ok, model} = Multilingual.train_cross_lingual(
        en_training_data,
        source_language: :en,
        target_languages: [:es, :ca],
        task: :pos_tagging,
        num_labels: 17
      )

      # Use the model for Spanish
      {:ok, tagged} = predict_for_language(model, spanish_tokens, :es)
  """
  @spec train_cross_lingual([FineTuner.training_example()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def train_cross_lingual(training_data, opts) do
    source_language = Keyword.fetch!(opts, :source_language)
    target_languages = Keyword.get(opts, :target_languages, [])
    task = Keyword.fetch!(opts, :task)

    Logger.info("Training cross-lingual model: #{source_language} → #{inspect(target_languages)}")

    # Use multilingual base model
    {:ok, base_model} = Loader.load_model(:xlm_roberta_base, opts)

    # Fine-tune on source language data
    case FineTuner.fine_tune(base_model, training_data, task, opts) do
      {:ok, finetuned_model} ->
        Logger.info("Cross-lingual model trained successfully")
        {:ok, Map.put(finetuned_model, :target_languages, target_languages)}

      error ->
        error
    end
  end

  @doc """
  Predicts using a cross-lingual model on target language text.

  ## Examples

      {:ok, predictions} = Multilingual.predict_cross_lingual(
        model,
        spanish_tokens,
        target_language: :es
      )
  """
  @spec predict_cross_lingual(map(), [Token.t()], keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def predict_cross_lingual(model, tokens, opts \\ []) do
    target_language = Keyword.get(opts, :target_language)

    if target_language do
      Logger.debug("Cross-lingual prediction for language: #{target_language}")
    end

    # Use TokenClassifier for prediction
    TokenClassifier.predict(model, tokens, opts)
  end

  @doc """
  Detects the language of input text.

  This is a simple heuristic-based detector. For production use,
    consider using a dedicated language detection library.

  ## Examples

      {:ok, language} = Multilingual.detect_language("Hello world")
      # => {:ok, :en}

      {:ok, language} = Multilingual.detect_language("Hola mundo")
      # => {:ok, :es}
  """
  @spec detect_language(String.t()) :: {:ok, atom()} | {:error, :unknown_language}
  def detect_language(text) do
    # Simple heuristic detection based on common words
    # In production, use a proper language detection library
    cond do
      # English indicators
      String.contains?(text, ["the ", "is ", "are ", "was ", "were "]) ->
        {:ok, :en}

      # Spanish indicators
      String.contains?(text, ["el ", "la ", "los ", "las ", "es ", "está "]) ->
        {:ok, :es}

      # Catalan indicators
      String.contains?(text, ["que ", "amb ", "dels ", "les "]) ->
        {:ok, :ca}

      # French indicators
      String.contains?(text, ["le ", "la ", "les ", "est ", "sont "]) ->
        {:ok, :fr}

      # German indicators
      String.contains?(text, ["der ", "die ", "das ", "ist ", "sind "]) ->
        {:ok, :de}

      true ->
        {:error, :unknown_language}
    end
  end

  @doc """
  Lists all available multilingual models.

  ## Examples

      Multilingual.available_models()
      # => [:xlm_roberta_base, :mbert, :xlm_mlm_100]
  """
  @spec available_models() :: [atom()]
  def available_models do
    Map.keys(@multilingual_models)
  end

  @doc """
  Gets information about a multilingual model.

  ## Examples

      {:ok, info} = Multilingual.model_info(:xlm_roberta_base)
      # => {:ok, %{languages: 100, best_for: [:cross_lingual, ...]}}
  """
  @spec model_info(atom()) :: {:ok, map()} | {:error, :unknown_model}
  def model_info(model_name) do
    case Map.fetch(@multilingual_models, model_name) do
      {:ok, info} -> {:ok, info}
      :error -> {:error, :unknown_model}
    end
  end

  @doc """
  Checks if a language is well-supported by multilingual models.

  ## Examples

      Multilingual.supported_language?(:es)
      # => true

      Multilingual.supported_language?(:tlh)  # Klingon
      # => false
  """
  @spec supported_language?(atom()) :: boolean()
  def supported_language?(language) do
    # XLM-RoBERTa supports 100 languages
    # This is a simplified list of major languages
    language in [
      :en,
      :es,
      :ca,
      :fr,
      :de,
      :it,
      :pt,
      :nl,
      :pl,
      :ru,
      :zh,
      :ja,
      :ko,
      :ar,
      :hi,
      :th,
      :vi,
      :tr,
      :he,
      :id,
      :ms,
      :fil,
      :sv,
      :no,
      :da,
      :fi,
      :cs,
      :ro,
      :hu,
      :el,
      :bg,
      :uk,
      :sr,
      :hr,
      :sk,
      :sl,
      :et,
      :lv,
      :lt
    ]
  end
end
