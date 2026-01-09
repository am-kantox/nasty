defmodule Nasty.Language.English.TransformerNER do
  @moduledoc """
  Transformer-based Named Entity Recognition for English.

  Uses pre-trained transformer models fine-tuned for NER to identify
  and classify named entities (persons, organizations, locations, etc.)
  using the BIO (Begin-Inside-Outside) tagging scheme.

  Expected F1 scores: 93-95% on CoNLL-2003.
  """

  alias Nasty.AST.Semantic.Entity
  alias Nasty.AST.Token
  alias Nasty.Statistics.ModelLoader
  alias Nasty.Statistics.Neural.Transformers.{Inference, Loader, TokenClassifier}

  require Logger

  # BIO tags for named entity recognition (9 tags)
  # Based on CoNLL-2003 entity types
  @bio_tags [
    :o,
    # Outside (not an entity)
    :b_per,
    # Begin Person
    :i_per,
    # Inside Person
    :b_org,
    # Begin Organization
    :i_org,
    # Inside Organization
    :b_loc,
    # Begin Location
    :i_loc,
    # Inside Location
    :b_misc,
    # Begin Miscellaneous
    :i_misc
    # Inside Miscellaneous
  ]

  # Label ID to BIO tag mapping (0-indexed)
  @label_map Enum.with_index(@bio_tags)
             |> Enum.into(%{}, fn {tag, id} ->
               {id, Atom.to_string(tag) |> String.upcase() |> String.replace("_", "-")}
             end)

  # BIO tag to label ID mapping (for training)
  @tag_to_id Enum.with_index(@bio_tags) |> Enum.into(%{}, fn {tag, id} -> {tag, id} end)

  @doc """
  Recognizes named entities in tokens using a transformer model.

  ## Options

    * `:model` - Model to use: atom name (e.g., :roberta_base) or :transformer (uses default)
    * `:cache_dir` - Directory for model caching
    * `:device` - Device to use (:cpu or :cuda, default: :cpu)
    * `:use_cache` - Whether to use prediction caching (default: true)

  ## Examples

      {:ok, tokens} = Tokenizer.tokenize("John lives in Paris")
      {:ok, entities} = TransformerNER.recognize_entities(tokens)

      # Use specific model
      {:ok, entities} = TransformerNER.recognize_entities(tokens, model: :bert_base_cased)

  """
  @spec recognize_entities([Token.t()], keyword()) :: {:ok, [Entity.t()]} | {:error, term()}
  def recognize_entities(tokens, opts \\ []) do
    model_name = resolve_model_name(opts)
    use_cache = Keyword.get(opts, :use_cache, true)

    # Tag tokens with BIO labels
    with {:ok, classifier} <- get_or_create_classifier(model_name, opts),
         {:ok, optimized} <- maybe_optimize(classifier, use_cache),
         {:ok, predictions} <- predict_with_model(optimized, tokens, opts),
         {:ok, tagged_tokens} <- update_tokens(tokens, predictions),
         {:ok, entities} <- extract_entities(tagged_tokens) do
      {:ok, entities}
    else
      {:error, reason} ->
        Logger.warning("Transformer NER failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.warning("Transformer NER failed: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Gets the label map (ID to BIO tag).

  ## Examples

      TransformerNER.label_map()
      # => %{0 => "O", 1 => "B-PER", 2 => "I-PER", ...}

  """
  @spec label_map() :: %{integer() => String.t()}
  def label_map, do: @label_map

  @doc """
  Gets the tag to ID map (BIO tag to ID).

  ## Examples

      TransformerNER.tag_to_id()
      # => %{o: 0, b_per: 1, i_per: 2, ...}

  """
  @spec tag_to_id() :: %{atom() => integer()}
  def tag_to_id, do: @tag_to_id

  @doc """
  Returns the number of NER labels.

  ## Examples

      TransformerNER.num_labels()
      # => 9

  """
  @spec num_labels() :: integer()
  def num_labels, do: length(@bio_tags)

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
    registry_key = :"transformer_ner_#{model_name}"

    case ModelLoader.load_latest(:en, registry_key) do
      {:ok, classifier} ->
        Logger.debug("Loaded fine-tuned transformer NER model: #{model_name}")
        {:ok, classifier}

      {:error, :not_found} ->
        Logger.debug("No fine-tuned NER model found for #{model_name}, using base model")
        :not_found
    end
  end

  defp create_classifier(model_name, opts) do
    Logger.info("Loading transformer base model for NER: #{model_name}")

    with {:ok, base_model} <- Loader.load_model(model_name, opts),
         {:ok, classifier} <-
           TokenClassifier.create(base_model,
             task: :ner,
             num_labels: num_labels(),
             label_map: @label_map,
             dropout_rate: 0.1
           ) do
      Logger.info("Created NER classifier with #{num_labels()} labels")
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
          # Convert label string to atom (e.g., "B-PER" -> :b_per)
          bio_tag =
            String.downcase(pred.label) |> String.replace("-", "_") |> String.to_atom()

          %{token | entity_label: bio_tag}
        end)

      {:ok, tagged}
    end
  end

  defp extract_entities(tagged_tokens) do
    # Group BIO tags into entities
    entities =
      tagged_tokens
      |> Enum.chunk_by(fn token -> get_entity_type(token.entity_label) end)
      |> Enum.filter(fn chunk ->
        # Filter out "O" (outside) chunks
        hd(chunk).entity_label != :o
      end)
      |> Enum.map(&build_entity/1)

    {:ok, entities}
  end

  defp get_entity_type(:o), do: nil

  defp get_entity_type(bio_tag) when is_atom(bio_tag) do
    # Extract entity type from BIO tag (e.g., :b_per -> :per, :i_loc -> :loc)
    case Atom.to_string(bio_tag) do
      <<_::binary-size(2), "_", type::binary>> -> String.to_atom(type)
      _ -> nil
    end
  end

  defp build_entity(tokens) do
    first_token = hd(tokens)
    last_token = List.last(tokens)
    entity_type = get_entity_type(first_token.entity_label)

    # Combine token texts
    text = Enum.map_join(tokens, " ", & &1.text)

    # Calculate span
    span = %{
      start_line: first_token.span.start_line,
      start_column: first_token.span.start_column,
      end_line: last_token.span.end_line,
      end_column: last_token.span.end_column,
      start_byte: first_token.span.start_byte,
      end_byte: last_token.span.end_byte
    }

    # Map entity type from CoNLL (per, org, loc, misc) to Entity types
    type = map_entity_type(entity_type)

    Entity.new(type, text, tokens, span)
  end

  # Map CoNLL-2003 entity types to Entity module types
  defp map_entity_type(:per), do: :person
  defp map_entity_type(:org), do: :org
  defp map_entity_type(:loc), do: :loc
  defp map_entity_type(_), do: :misc
end
