defmodule Nasty.Language.English.POSTagger do
  @moduledoc """
  Part-of-Speech tagger for English using rule-based pattern matching.

  Tags tokens with Universal Dependencies POS tags based on:
  - Lexical lookup (closed-class words)
  - Morphological patterns (suffixes)
  - Context-based disambiguation

  This is a simple rule-based tagger. For better accuracy, consider
  using statistical models or neural networks in the future.

  ## Examples

      iex> alias Nasty.Language.English.{Tokenizer, POSTagger}
      iex> {:ok, tokens} = Tokenizer.tokenize("the")
      iex> {:ok, tagged} = POSTagger.tag_pos(tokens)
      iex> hd(tagged).pos_tag
      :det
  """

  alias Nasty.AST.Token
  alias Nasty.Language.English.TransformerPOSTagger
  alias Nasty.Language.Resources.LexiconLoader
  alias Nasty.Statistics.{ModelLoader, POSTagging.HMMTagger, POSTagging.NeuralTagger}

  require Logger

  # Load lexicons at compile time for performance
  @determiners LexiconLoader.load(:en, :determiners)
  @pronouns LexiconLoader.load(:en, :pronouns)
  @prepositions LexiconLoader.load(:en, :prepositions)
  @conjunctions_coord LexiconLoader.load(:en, :conjunctions_coord)
  @conjunctions_sub LexiconLoader.load(:en, :conjunctions_sub)
  @auxiliaries LexiconLoader.load(:en, :auxiliaries)
  @adverbs LexiconLoader.load(:en, :adverbs)
  @particles LexiconLoader.load(:en, :particles)
  @interjections LexiconLoader.load(:en, :interjections)
  @common_verbs LexiconLoader.load(:en, :common_verbs)
  @common_adjectives LexiconLoader.load(:en, :common_adjectives)

  # Extract base forms (stems) from common verbs for 3sg detection
  @common_verb_stems @common_verbs
                     |> Enum.map(fn verb ->
                       cond do
                         String.ends_with?(verb, "ing") and String.length(verb) > 4 ->
                           String.slice(verb, 0..(String.length(verb) - 4))

                         String.ends_with?(verb, "ed") and String.length(verb) > 3 ->
                           String.slice(verb, 0..(String.length(verb) - 3))

                         String.ends_with?(verb, "s") and String.length(verb) > 2 ->
                           String.slice(verb, 0..(String.length(verb) - 2))

                         true ->
                           verb
                       end
                     end)
                     |> Enum.uniq()

  @doc """
  Tags a list of tokens with POS tags.

  Uses:
  1. Lexical lookup for known words (determiners, pronouns, etc.)
  2. Morphological patterns (suffixes for verbs, nouns, adjectives)
  3. Context rules (e.g., word after determiner is likely a noun)
  4. Statistical models (HMM)
  5. Neural models (BiLSTM-CRF)

  ## Parameters

    - `tokens` - List of Token structs (from tokenizer)
    - `opts` - Options
      - `:model` - Model type: `:rule_based` (default), `:hmm`, `:neural`, `:ensemble`, `:neural_ensemble`, `:transformer`, or specific transformer model name (e.g., `:roberta_base`)
      - `:hmm_model` - Trained HMM model (optional)
      - `:neural_model` - Trained neural model (optional)

  ## Returns

    - `{:ok, tokens}` - Tokens with updated pos_tag field
  """
  @spec tag_pos([Token.t()], keyword()) :: {:ok, [Token.t()]}
  def tag_pos(tokens, opts \\ []) do
    model_type = Keyword.get(opts, :model, :rule_based)

    case model_type do
      :rule_based ->
        tag_pos_rule_based(tokens)

      :hmm ->
        tag_pos_hmm(tokens, opts)

      :neural ->
        tag_pos_neural(tokens, opts)

      :ensemble ->
        tag_pos_ensemble(tokens, opts)

      :neural_ensemble ->
        tag_pos_neural_ensemble(tokens, opts)

      :transformer ->
        tag_pos_transformer(tokens, opts)

      model_name when is_atom(model_name) ->
        # Check if it's a transformer model name
        if transformer_model?(model_name) do
          tag_pos_transformer(tokens, Keyword.put(opts, :model, model_name))
        else
          {:error, {:unknown_model_type, model_type}}
        end

      _ ->
        {:error, {:unknown_model_type, model_type}}
    end
  end

  @doc """
  Rule-based POS tagging (original implementation).
  """
  def tag_pos_rule_based(tokens) do
    tagged =
      tokens
      |> Enum.with_index()
      |> Enum.map(fn {token, idx} ->
        tag_token(token, tokens, idx)
      end)

    {:ok, tagged}
  end

  @doc """
  HMM-based POS tagging.

  If no model is provided via `:hmm_model` option, attempts to load
  the latest English POS tagging model from the registry. Falls back
  to rule-based tagging if no model is available.
  """
  def tag_pos_hmm(tokens, opts) do
    hmm_model =
      case Keyword.get(opts, :hmm_model) do
        nil ->
          # Try to load from registry
          case ModelLoader.load_latest(:en, :pos_tagging) do
            {:ok, model} ->
              Logger.debug("Loaded HMM POS model from registry")
              model

            {:error, :not_found} ->
              Logger.warning(
                "No HMM POS model found. Falling back to rule-based tagging. " <>
                  "Train a model using: mix nasty.train.pos"
              )

              nil
          end

        model ->
          model
      end

    case hmm_model do
      nil ->
        # Fallback to rule-based
        tag_pos_rule_based(tokens)

      %Nasty.Statistics.POSTagging.HMMTagger{} = model ->
        words = Enum.map(tokens, & &1.text)

        case HMMTagger.predict(model, words, []) do
          {:ok, tags} ->
            tagged =
              Enum.zip(tokens, tags)
              |> Enum.map(fn {token, tag} -> %{token | pos_tag: tag} end)

            {:ok, tagged}

          {:error, reason} ->
            {:error, reason}
        end

      _invalid_model ->
        # Model is not an HMM model, fallback to rule-based
        Logger.warning("Invalid HMM model type, falling back to rule-based tagging")
        tag_pos_rule_based(tokens)
    end
  end

  @doc """
  Neural POS tagging using BiLSTM-CRF.

  If no model is provided via `:neural_model` option, attempts to load
  the latest neural POS tagging model from the registry. Falls back
  to HMM or rule-based tagging if no model is available.
  """
  def tag_pos_neural(tokens, opts) do
    neural_model =
      case Keyword.get(opts, :neural_model) do
        nil ->
          # Try to load from registry
          case ModelLoader.load_latest(:en, :pos_tagging_neural) do
            {:ok, model} ->
              Logger.debug("Loaded neural POS model from registry")
              model

            {:error, :not_found} ->
              Logger.warning(
                "No neural POS model found. Falling back to HMM tagging. " <>
                  "Train a model using: mix nasty.train.neural.pos"
              )

              nil
          end

        model ->
          model
      end

    case neural_model do
      nil ->
        # Fallback to HMM
        tag_pos_hmm(tokens, opts)

      model ->
        words = Enum.map(tokens, & &1.text)

        case NeuralTagger.predict(model, words, []) do
          {:ok, tags} ->
            tagged =
              Enum.zip(tokens, tags)
              |> Enum.map(fn {token, tag} -> %{token | pos_tag: tag} end)

            {:ok, tagged}

          {:error, reason} ->
            Logger.warning("Neural tagging failed: #{inspect(reason)}, falling back to HMM")
            tag_pos_hmm(tokens, opts)
        end
    end
  end

  @doc """
  Ensemble POS tagging combining rule-based and HMM.

  Uses HMM predictions but falls back to rule-based for punctuation
  and other deterministic cases.
  """
  def tag_pos_ensemble(tokens, opts) do
    with {:ok, rule_tokens} <- tag_pos_rule_based(tokens),
         {:ok, hmm_tokens} <- tag_pos_hmm(tokens, opts) do
      # Prefer rule-based for punctuation, numbers, and high-confidence cases
      ensemble_tokens =
        Enum.zip(rule_tokens, hmm_tokens)
        |> Enum.map(fn
          {%{pos_tag: pos_tag} = rule_token, _hmm_token} when pos_tag in [:punct, :num] ->
            rule_token

          {_rule_token, hmm_token} ->
            hmm_token
        end)

      {:ok, ensemble_tokens}
    end
  end

  @doc """
  Neural ensemble POS tagging combining neural, HMM, and rule-based models.

  Uses neural predictions as primary, with fallback chain:
  neural -> HMM -> rule-based

  Prefers rule-based for high-confidence cases like punctuation and numbers.
  """
  def tag_pos_neural_ensemble(tokens, opts) do
    with {:ok, rule_tokens} <- tag_pos_rule_based(tokens),
         {:ok, neural_tokens} <- tag_pos_neural(tokens, opts) do
      # Prefer rule-based for punctuation and numbers, otherwise use neural
      ensemble_tokens =
        Enum.zip(rule_tokens, neural_tokens)
        |> Enum.map(fn
          {%{pos_tag: pos_tag} = rule_token, _neural_token}
          when pos_tag in [:punct, :num] ->
            rule_token

          {_rule_token, neural_token} ->
            neural_token
        end)

      {:ok, ensemble_tokens}
    end
  end

  @doc """
  Transformer-based POS tagging using pre-trained models.

  Uses BERT, RoBERTa, or other transformer models for state-of-the-art
  accuracy (98-99%). Falls back to neural tagging if transformer fails.
  """
  def tag_pos_transformer(tokens, opts) do
    case TransformerPOSTagger.tag_pos(tokens, opts) do
      {:ok, tagged} ->
        {:ok, tagged}

      {:error, reason} ->
        Logger.warning("Transformer tagging failed: #{inspect(reason)}, falling back to neural")
        tag_pos_neural(tokens, opts)
    end
  end

  # Check if model name is a known transformer model
  defp transformer_model?(model_name) do
    model_name in [
      :bert_base_cased,
      :bert_base_uncased,
      :roberta_base,
      :xlm_roberta_base,
      :distilbert_base
    ]
  end

  ## Private Functions

  # Tag a single token based on lexical lookup, morphology, and context
  defp tag_token(token, all_tokens, idx) do
    # Skip if already has a definitive tag
    if token.pos_tag in [:num, :punct] do
      token
    else
      lowercase = String.downcase(token.text)

      # Try lexical lookup first
      # Default fallback
      tag =
        lexical_tag(lowercase) ||
          morphological_tag(token.text) ||
          contextual_tag(token, all_tokens, idx) ||
          :noun

      %{token | pos_tag: tag}
    end
  end

  # Lexical lookup for closed-class words
  # Note: Order matters for ambiguous words
  defp lexical_tag(word) do
    cond do
      # Determiners first (includes possessives: my, your, his, her, its, our, their)
      word in determiners() -> :det
      # Pronouns (non-ambiguous ones)
      word in pronouns() -> :pron
      word in prepositions() -> :adp
      word in conjunctions_coord() -> :cconj
      word in conjunctions_sub() -> :sconj
      word in auxiliaries() -> :aux
      word in common_verbs() -> :verb
      word in common_adjectives() -> :adj
      word in adverbs() -> :adv
      word in particles() -> :part
      word in interjections() -> :intj
      true -> nil
    end
  end

  # Morphological tagging based on suffixes
  # credo:disable-for-lines:84
  defp morphological_tag(word) do
    cond do
      # Nouns (check specific noun suffixes first before other patterns)
      String.ends_with?(word, "tion") ->
        :noun

      String.ends_with?(word, "sion") ->
        :noun

      String.ends_with?(word, "ment") ->
        :noun

      String.ends_with?(word, "ness") ->
        :noun

      String.ends_with?(word, "ity") ->
        :noun

      String.ends_with?(word, "ism") ->
        :noun

      # Adverbs (specific suffix)
      String.ends_with?(word, "ly") and String.length(word) > 3 ->
        :adv

      # Verbs
      String.ends_with?(word, "ing") and String.length(word) > 4 ->
        :verb

      String.ends_with?(word, "ed") and String.length(word) > 3 ->
        :verb

      # Third-person singular present tense
      # Verbs ending in -s/-es: walks, runs, sleeps, goes, does, watches
      # Only tag as verb if stem is in common verbs list or has verb markers
      # This avoids mistagging plural nouns as verbs
      third_person_singular_verb?(word) ->
        :verb

      # Adjectives
      String.ends_with?(word, "ful") ->
        :adj

      String.ends_with?(word, "less") ->
        :adj

      String.ends_with?(word, "ous") ->
        :adj

      String.ends_with?(word, "ive") ->
        :adj

      String.ends_with?(word, "able") ->
        :adj

      String.ends_with?(word, "ible") ->
        :adj

      # Proper nouns (capitalized)
      String.first(word) == String.upcase(String.first(word)) and String.length(word) > 1 ->
        :propn

      # Nouns ending in -er/-or (less specific, so later)
      String.ends_with?(word, "er") and String.length(word) > 3 ->
        :noun

      String.ends_with?(word, "or") and String.length(word) > 3 ->
        :noun

      String.ends_with?(word, "ist") ->
        :noun

      true ->
        nil
    end
  end

  # Context-based tagging
  defp contextual_tag(token, all_tokens, idx) do
    prev_token = if idx > 0, do: Enum.at(all_tokens, idx - 1)
    next_token = Enum.at(all_tokens, idx + 1)

    lowercase = String.downcase(token.text)

    cond do
      # Sentence-initial capitalized word followed by noun/pronoun -> likely verb (imperative)
      # e.g., "Filter users", "Sort the list", "Find active items"
      idx == 0 && next_token && next_token.pos_tag in [:noun, :det, :pron] &&
          lowercase in common_verb_stems() ->
        :verb

      # Object pronouns after verb or preposition: me, him, her, us, them
      (lowercase in ~w(me him her us them) and prev_token) &&
          prev_token.pos_tag in [:verb, :adp] ->
        :pron

      # After determiner -> likely noun
      prev_token && prev_token.pos_tag == :det ->
        :noun

      # After preposition -> likely noun
      prev_token && prev_token.pos_tag == :adp ->
        :noun

      # Before noun -> likely adjective
      next_token && next_token.pos_tag == :noun ->
        :adj

      true ->
        nil
    end
  end

  # Check if word ends with a clear noun suffix that should not be treated as verb
  defp ends_with_noun_suffix?(word) do
    String.ends_with?(word, "tions") or
      String.ends_with?(word, "sions") or
      String.ends_with?(word, "ments") or
      String.ends_with?(word, "nesses") or
      String.ends_with?(word, "ities") or
      String.ends_with?(word, "isms") or
      String.ends_with?(word, "ers") or
      String.ends_with?(word, "ors") or
      String.ends_with?(word, "ists")
  end

  # Check if word is likely a third-person singular verb (ends in -s/-es)
  # Conservative approach: check if stem is in common verbs list
  defp third_person_singular_verb?(word) do
    cond do
      # Exclude capitalized words (proper nouns)
      String.first(word) == String.upcase(String.first(word)) ->
        false

      # Exclude words with clear noun suffixes
      ends_with_noun_suffix?(word) ->
        false

      # Check if stem (word without -s/-es) is in common verbs
      String.ends_with?(word, "es") and String.length(word) > 3 ->
        stem = String.slice(word, 0..(String.length(word) - 3))
        stem in common_verb_stems()

      String.ends_with?(word, "s") and String.length(word) > 2 ->
        stem = String.slice(word, 0..(String.length(word) - 2))
        stem in common_verb_stems()

      true ->
        false
    end
  end

  # Return loaded lexicons from module attributes
  defp common_verb_stems, do: @common_verb_stems

  defp determiners, do: @determiners
  defp pronouns, do: @pronouns
  defp prepositions, do: @prepositions
  defp conjunctions_coord, do: @conjunctions_coord
  defp conjunctions_sub, do: @conjunctions_sub
  defp auxiliaries, do: @auxiliaries
  defp adverbs, do: @adverbs
  defp particles, do: @particles
  defp interjections, do: @interjections
  defp common_verbs, do: @common_verbs
  defp common_adjectives, do: @common_adjectives
end
