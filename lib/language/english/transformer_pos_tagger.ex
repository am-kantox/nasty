defmodule Nasty.Language.English.TransformerPOSTagger do
  @moduledoc """
  Transformer-based Part-of-Speech tagger for English.

  Uses pre-trained transformer models (BERT, RoBERTa, etc.) fine-tuned
  for POS tagging to achieve state-of-the-art accuracy (98-99%).

  The tagger supports multiple transformer models and provides seamless
  integration with the existing Nasty POS tagging API.
  """

  alias Nasty.AST.Token
  alias Nasty.Statistics.ModelLoader
  alias Nasty.Statistics.Neural.Transformers.{Inference, Loader, TokenClassifier}

  require Logger

  # Universal Dependencies POS tags (17 tags)
  @upos_tags [
    :adj,
    # adjective
    :adp,
    # adposition
    :adv,
    # adverb
    :aux,
    # auxiliary
    :cconj,
    # coordinating conjunction
    :det,
    # determiner
    :intj,
    # interjection
    :noun,
    # noun
    :num,
    # numeral
    :part,
    # particle
    :pron,
    # pronoun
    :propn,
    # proper noun
    :punct,
    # punctuation
    :sconj,
    # subordinating conjunction
    :sym,
    # symbol
    :verb,
    # verb
    :x
    # other
  ]

  # Label ID to UPOS tag mapping (0-indexed)
  @label_map Enum.with_index(@upos_tags)
             |> Enum.into(%{}, fn {tag, id} -> {id, Atom.to_string(tag) |> String.upcase()} end)

  # UPOS tag to label ID mapping (for training)
  @tag_to_id Enum.with_index(@upos_tags) |> Enum.into(%{}, fn {tag, id} -> {tag, id} end)

  @doc """
  Tags tokens with POS tags using a transformer model.

  ## Options

    * `:model` - Model to use: atom name (e.g., :roberta_base) or :transformer (uses default)
    * `:cache_dir` - Directory for model caching
    * `:device` - Device to use (:cpu or :cuda, default: :cpu)
    * `:use_cache` - Whether to use prediction caching (default: true)

  ## Examples

      {:ok, tokens} = Tokenizer.tokenize("The cat sat")
      {:ok, tagged} = TransformerPOSTagger.tag_pos(tokens)

      # Use specific model
      {:ok, tagged} = TransformerPOSTagger.tag_pos(tokens, model: :bert_base_cased)

      # Disable caching for variable inputs
      {:ok, tagged} = TransformerPOSTagger.tag_pos(tokens, use_cache: false)

  """
  @spec tag_pos([Token.t()], keyword()) :: {:ok, [Token.t()]} | {:error, term()}
  def tag_pos(tokens, opts \\ []) do
    model_name = resolve_model_name(opts)
    use_cache = Keyword.get(opts, :use_cache, true)

    # Try to load or create classifier
    with {:ok, classifier} <- get_or_create_classifier(model_name, opts),
         {:ok, optimized} <- maybe_optimize(classifier, use_cache),
         {:ok, predictions} <- predict_with_model(optimized, tokens, opts),
         {:ok, tagged} <- update_tokens(tokens, predictions) do
      {:ok, tagged}
    else
      {:error, reason} ->
        Logger.warning("Transformer POS tagging failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.warning("Transformer POS tagging failed: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Gets the label map (ID to UPOS tag).

  ## Examples

      TransformerPOSTagger.label_map()
      # => %{0 => "ADJ", 1 => "ADP", ...}

  """
  @spec label_map() :: %{integer() => String.t()}
  def label_map, do: @label_map

  @doc """
  Gets the tag to ID map (UPOS tag to ID).

  ## Examples

      TransformerPOSTagger.tag_to_id()
      # => %{adj: 0, adp: 1, ...}

  """
  @spec tag_to_id() :: %{atom() => integer()}
  def tag_to_id, do: @tag_to_id

  @doc """
  Returns the number of POS labels.

  ## Examples

      TransformerPOSTagger.num_labels()
      # => 17

  """
  @spec num_labels() :: integer()
  def num_labels, do: length(@upos_tags)

  # Private functions

  defp resolve_model_name(opts) do
    case Keyword.get(opts, :model, :transformer) do
      :transformer -> :roberta_base
      model_name -> model_name
    end
  end

  defp get_or_create_classifier(model_name, opts) do
    # Try to load from registry first (fine-tuned model)
    case load_from_registry(model_name) do
      {:ok, classifier} ->
        {:ok, classifier}

      :not_found ->
        # Create new classifier from base model
        create_classifier(model_name, opts)
    end
  end

  defp load_from_registry(model_name) do
    registry_key = :"transformer_pos_#{model_name}"

    case ModelLoader.load_latest(:en, registry_key) do
      {:ok, classifier} ->
        Logger.debug("Loaded fine-tuned transformer POS model: #{model_name}")
        {:ok, classifier}

      {:error, :not_found} ->
        Logger.debug("No fine-tuned model found for #{model_name}, using base model")
        :not_found
    end
  end

  defp create_classifier(model_name, opts) do
    Logger.info("Loading transformer base model: #{model_name}")

    with {:ok, base_model} <- Loader.load_model(model_name, opts),
         {:ok, classifier} <-
           TokenClassifier.create(base_model,
             task: :pos_tagging,
             num_labels: num_labels(),
             label_map: @label_map,
             dropout_rate: 0.1
           ) do
      Logger.info("Created POS classifier with #{num_labels()} labels")
      {:ok, classifier}
    end
  end

  defp maybe_optimize(classifier, use_cache) do
    if use_cache do
      Inference.optimize_for_inference(classifier, optimizations: [:cache])
    else
      {:ok, %{classifier: classifier, optimizations: [], cache: nil, compiled_serving: nil}}
    end
  end

  defp predict_with_model(%{optimizations: optimizations} = optimized, tokens, opts) do
    if :cache in optimizations do
      Inference.predict(optimized, tokens, opts)
    else
      TokenClassifier.predict(optimized.classifier, tokens, opts)
    end
  end

  defp update_tokens(tokens, predictions) do
    if length(tokens) != length(predictions) do
      {:error, :token_prediction_mismatch}
    else
      tagged =
        Enum.zip(tokens, predictions)
        |> Enum.map(fn {token, pred} ->
          # Convert label string to atom (e.g., "NOUN" -> :noun)
          pos_tag = String.downcase(pred.label) |> String.to_atom()
          %{token | pos_tag: pos_tag}
        end)

      {:ok, tagged}
    end
  end
end
