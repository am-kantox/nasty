defmodule Nasty.Data.OntoNotes do
  @moduledoc """
  Loader for OntoNotes 5.0 coreference data in CoNLL-2012 format.

  The CoNLL-2012 format extends CoNLL-U with coreference annotations in the
  last column. Each token has a coreference column indicating which entity
  chain(s) it belongs to.

  ## Format

  CoNLL-2012 has the following tab-separated columns:
  1. Document ID
  2. Part number
  3. Word number
  4. Word itself
  5. POS tag
  6. Parse bit
  7. Predicate lemma
  8. Predicate sense
  9. Word sense
  10. Speaker
  11. Named entities
  12. Coreference chains (e.g., "(0)" or "(0|(1" or "0)")

  ## Example

      # Begin document doc1; part 000
      doc1  0   0   John    NNP  ...  -  -  -  -  *  (0
      doc1  0   1   works   VBZ  ...  -  -  -  -  *  -
      doc1  0   2   at      IN   ...  -  -  -  -  *  -
      doc1  0   3   Google  NNP  ...  -  -  -  -  *  (1)
      doc1  0   4   .       .    ...  -  -  -  -  *  -
      # ...
      doc1  0   10  He      PRP  ...  -  -  -  -  *  0)
      # End document

  ## Usage

      # Load training data
      {:ok, documents} = OntoNotes.load_documents("data/ontonotes/train")

      # Extract mention pairs for training
      pairs = OntoNotes.extract_mention_pairs(documents, max_distance: 3)

      # Create balanced training data
      training_data = OntoNotes.create_training_data(documents,
        positive_negative_ratio: 1.0,
        max_distance: 3
      )
  """

  alias Nasty.AST.Semantic.{CorefChain, Mention}

  @type coref_document :: %{
          id: String.t(),
          sentences: [coref_sentence()],
          chains: [CorefChain.t()]
        }

  @type coref_sentence :: %{
          tokens: [coref_token()],
          mentions: [Mention.t()]
        }

  @type coref_token :: %{
          id: pos_integer(),
          text: String.t(),
          pos_tag: atom(),
          coref_ids: [non_neg_integer()]
        }

  @type mention_pair :: %{
          mention1: Mention.t(),
          mention2: Mention.t(),
          label: 0 | 1,
          document_id: String.t()
        }

  @doc """
  Load OntoNotes documents from a directory.

  Recursively searches for .coref files in the given directory.

  ## Parameters

    - `path` - Path to directory containing CoNLL-2012 files

  ## Returns

    - `{:ok, documents}` - List of parsed documents with coreference annotations
    - `{:error, reason}` - Load error
  """
  @spec load_documents(Path.t()) :: {:ok, [coref_document()]} | {:error, term()}
  def load_documents(path) do
    if File.dir?(path) do
      files =
        Path.wildcard(Path.join(path, "**/*.v4_gold_conll"))
        |> Enum.concat(Path.wildcard(Path.join(path, "**/*.coref")))

      documents =
        files
        |> Enum.map(&load_document/1)
        |> Enum.filter(fn
          {:ok, _} -> true
          _ -> false
        end)
        |> Enum.map(fn {:ok, doc} -> doc end)

      {:ok, documents}
    else
      {:error, :not_a_directory}
    end
  end

  @doc """
  Load a single OntoNotes document file.

  ## Parameters

    - `path` - Path to .coref or .v4_gold_conll file

  ## Returns

    - `{:ok, document}` - Parsed document with coreference annotations
    - `{:error, reason}` - Parse error
  """
  @spec load_document(Path.t()) :: {:ok, coref_document()} | {:error, term()}
  def load_document(path) do
    with {:ok, content} <- File.read(path),
         do: parse_conll2012(content, Path.basename(path, ".coref"))
  end

  @doc """
  Extract mention pairs from documents for training.

  Generates both positive pairs (mentions in same chain) and negative pairs
  (mentions not in same chain).

  ## Options

    - `:max_distance` - Maximum sentence distance between mentions (default: 3)
    - `:positive_negative_ratio` - Ratio of positive to negative samples (default: 1.0)
    - `:window_size` - Number of sentences to consider for negative sampling (default: 5)

  ## Returns

  List of mention pairs with labels (1 for coref, 0 for non-coref)
  """
  @spec extract_mention_pairs([coref_document()], keyword()) :: [mention_pair()]
  def extract_mention_pairs(documents, opts \\ []) do
    max_distance = Keyword.get(opts, :max_distance, 3)
    ratio = Keyword.get(opts, :positive_negative_ratio, 1.0)

    Enum.flat_map(documents, fn doc ->
      positive_pairs = extract_positive_pairs(doc, max_distance)
      negative_pairs = extract_negative_pairs(doc, max_distance, length(positive_pairs), ratio)

      positive_pairs ++ negative_pairs
    end)
  end

  @doc """
  Create training data from documents.

  This is a convenience function that extracts mention pairs and formats them
  for training a neural coreference model.

  ## Options

    - `:positive_negative_ratio` - Ratio of positive to negative samples (default: 1.0)
    - `:max_distance` - Maximum sentence distance (default: 3)
    - `:shuffle` - Whether to shuffle the data (default: true)
    - `:seed` - Random seed for shuffling (default: :os.system_time())

  ## Returns

  List of {mention1, mention2, label} tuples ready for training
  """
  @spec create_training_data([coref_document()], keyword()) :: [{Mention.t(), Mention.t(), 0 | 1}]
  def create_training_data(documents, opts \\ []) do
    shuffle = Keyword.get(opts, :shuffle, true)
    seed = Keyword.get(opts, :seed, :os.system_time())

    pairs = extract_mention_pairs(documents, opts)

    data = Enum.map(pairs, fn pair -> {pair.mention1, pair.mention2, pair.label} end)

    if shuffle do
      :rand.seed(:exsss, {seed, seed, seed})
      Enum.shuffle(data)
    else
      data
    end
  end

  ## Private Functions

  # Parse CoNLL-2012 format
  defp parse_conll2012(content, doc_id) do
    lines = String.split(content, "\n", trim: true)

    {sentences, chains} = parse_lines(lines, [], %{}, 0)

    chains_list =
      chains
      |> Enum.map(fn {chain_id, mentions} ->
        representative = select_representative(mentions)
        CorefChain.new(chain_id, mentions, representative)
      end)
      |> Enum.sort_by(& &1.id)

    {:ok,
     %{
       id: doc_id,
       sentences: Enum.reverse(sentences),
       chains: chains_list
     }}
  end

  # Parse lines and build sentences with mentions
  defp parse_lines([], sentences, chains, _sent_idx), do: {sentences, chains}

  defp parse_lines([line | rest], sentences, chains, sent_idx) do
    cond do
      String.starts_with?(line, "#") ->
        # Comment line, skip
        parse_lines(rest, sentences, chains, sent_idx)

      String.trim(line) == "" ->
        # Empty line, skip
        parse_lines(rest, sentences, chains, sent_idx)

      true ->
        # Token line
        case parse_token_line(line, sent_idx) do
          {:ok, token, coref_ids} ->
            # Accumulate tokens until sentence break or end
            {sentence_tokens, remaining_lines, new_sent_idx} =
              collect_sentence([{token, coref_ids} | []], rest, sent_idx)

            # Build mentions from tokens
            mentions = build_mentions_from_tokens(sentence_tokens, sent_idx)

            # Update chains
            new_chains = update_chains(chains, mentions)

            # Create sentence
            sentence = %{
              tokens: Enum.map(sentence_tokens, fn {tok, _} -> tok end),
              mentions: mentions
            }

            parse_lines(remaining_lines, [sentence | sentences], new_chains, new_sent_idx + 1)

          :skip ->
            parse_lines(rest, sentences, chains, sent_idx)
        end
    end
  end

  # Collect tokens for a single sentence
  defp collect_sentence(acc, [], sent_idx), do: {Enum.reverse(acc), [], sent_idx}

  defp collect_sentence(acc, [line | rest], sent_idx) do
    if String.starts_with?(line, "#") or String.trim(line) == "" do
      {Enum.reverse(acc), [line | rest], sent_idx}
    else
      case parse_token_line(line, sent_idx) do
        {:ok, token, coref_ids} ->
          collect_sentence([{token, coref_ids} | acc], rest, sent_idx)

        :skip ->
          collect_sentence(acc, rest, sent_idx)
      end
    end
  end

  # Parse a single token line
  defp parse_token_line(line, sent_idx) do
    parts = String.split(line, "\t")

    if length(parts) >= 4 do
      # Minimal parsing for coreference
      # Format: doc_id part word_num word pos ... coref
      word = Enum.at(parts, 3)
      pos = Enum.at(parts, 4)
      coref_col = List.last(parts)

      token = %{
        id: sent_idx,
        text: word,
        pos_tag: parse_pos_tag(pos),
        coref_ids: parse_coref_column(coref_col)
      }

      {:ok, token, token.coref_ids}
    else
      :skip
    end
  end

  # Parse POS tag to internal format
  # credo:disable-for-lines:25
  defp parse_pos_tag(pos) do
    case pos do
      "NN" -> :noun
      "NNS" -> :noun
      "NNP" -> :propn
      "NNPS" -> :propn
      "VB" -> :verb
      "VBD" -> :verb
      "VBG" -> :verb
      "VBN" -> :verb
      "VBP" -> :verb
      "VBZ" -> :verb
      "JJ" -> :adj
      "JJR" -> :adj
      "JJS" -> :adj
      "RB" -> :adv
      "RBR" -> :adv
      "RBS" -> :adv
      "DT" -> :det
      "IN" -> :adp
      "PRP" -> :pron
      "PRP$" -> :pron
      _ -> :other
    end
  end

  # Parse coreference column (e.g., "(0)", "(0|(1", "0)", "-")
  defp parse_coref_column("-"), do: []
  defp parse_coref_column("_"), do: []

  defp parse_coref_column(coref) do
    # Extract all chain IDs from the coref annotation
    Regex.scan(~r/\d+/, coref)
    |> Enum.map(fn [id] -> String.to_integer(id) end)
    |> Enum.uniq()
  end

  # Build mentions from tokens with coref annotations
  defp build_mentions_from_tokens(token_coref_pairs, sent_idx) do
    # Group consecutive tokens by chain ID
    token_coref_pairs
    |> Enum.with_index()
    |> Enum.flat_map(fn {{token, coref_ids}, tok_idx} ->
      Enum.map(coref_ids, fn chain_id ->
        {chain_id, tok_idx, token}
      end)
    end)
    |> Enum.group_by(fn {chain_id, _, _} -> chain_id end)
    |> Enum.flat_map(fn {chain_id, token_group} ->
      # Each group represents a mention (one or more consecutive tokens)
      tokens = Enum.map(token_group, fn {_, _, tok} -> tok end)
      first_tok_idx = token_group |> List.first() |> elem(1)

      text = Enum.map_join(tokens, " ", & &1.text)

      [
        Mention.new(
          text,
          :proper_name,
          sent_idx,
          first_tok_idx,
          nil,
          tokens: tokens,
          chain_id: chain_id
        )
      ]
    end)
  end

  # Update coreference chains with new mentions
  defp update_chains(chains, mentions) do
    Enum.reduce(mentions, chains, fn mention, acc ->
      chain_id = mention.chain_id

      Map.update(acc, chain_id, [mention], fn existing ->
        [mention | existing]
      end)
    end)
  end

  # Select representative mention (prefer proper names)
  defp select_representative([]), do: ""

  defp select_representative(mentions) do
    # Sort by sentence index to get first mention
    sorted = Enum.sort_by(mentions, & &1.sentence_idx)
    first = List.first(sorted)
    first.text
  end

  # Extract positive pairs (mentions in same chain)
  defp extract_positive_pairs(doc, max_distance) do
    doc.chains
    |> Enum.flat_map(fn chain ->
      mentions = chain.mentions |> Enum.sort_by(& &1.sentence_idx)

      for {m1, idx1} <- Enum.with_index(mentions),
          {m2, idx2} <- Enum.with_index(mentions),
          idx1 < idx2,
          abs(m1.sentence_idx - m2.sentence_idx) <= max_distance do
        %{
          mention1: m1,
          mention2: m2,
          label: 1,
          document_id: doc.id
        }
      end
    end)
  end

  # Extract negative pairs (mentions not in same chain)
  defp extract_negative_pairs(doc, max_distance, num_positive, ratio) do
    num_negative = round(num_positive * ratio)

    all_mentions =
      doc.sentences
      |> Enum.with_index()
      |> Enum.flat_map(fn {sent, idx} ->
        Enum.map(sent.mentions, &%{&1 | sentence_idx: idx})
      end)

    # Generate candidate negative pairs
    candidates =
      for {m1, idx1} <- Enum.with_index(all_mentions),
          {m2, idx2} <- Enum.with_index(all_mentions),
          idx1 < idx2,
          abs(m1.sentence_idx - m2.sentence_idx) <= max_distance,
          m1.chain_id != m2.chain_id do
        %{
          mention1: m1,
          mention2: m2,
          label: 0,
          document_id: doc.id
        }
      end

    # Sample randomly
    :rand.seed(:exsss, {:os.system_time(), 0, 0})
    Enum.take_random(candidates, min(num_negative, length(candidates)))
  end

  @doc """
  Create span-based training data for end-to-end coreference.

  Generates (span, label) pairs where label is 1 if the span is a mention,
  0 otherwise. Also generates candidate spans using enumeration.

  ## Options

    - `:max_span_width` - Maximum span width in tokens (default: 10)
    - `:negative_span_ratio` - Ratio of negative to positive spans (default: 3.0)

  ## Returns

  List of {span, label} tuples
  """
  @spec create_span_training_data([coref_document()], keyword()) :: [{map(), 0 | 1}]
  def create_span_training_data(documents, opts \\ []) do
    max_span_width = Keyword.get(opts, :max_span_width, 10)
    negative_ratio = Keyword.get(opts, :negative_span_ratio, 3.0)

    Enum.flat_map(documents, fn doc ->
      # Get gold mentions
      gold_mentions =
        doc.chains
        |> Enum.flat_map(& &1.mentions)
        |> Enum.map(fn m ->
          {m.sentence_idx, m.token_idx, m.token_idx + length(m.tokens) - 1}
        end)
        |> MapSet.new()

      # Generate candidate spans
      candidate_spans =
        doc.sentences
        |> Enum.with_index()
        |> Enum.flat_map(fn {sent, sent_idx} ->
          num_tokens = length(sent.tokens)

          for start_idx <- 0..(num_tokens - 1),
              width <- 1..min(max_span_width, num_tokens - start_idx) do
            end_idx = start_idx + width - 1

            span = %{
              sentence_idx: sent_idx,
              start_idx: start_idx,
              end_idx: end_idx,
              tokens: Enum.slice(sent.tokens, start_idx..end_idx)
            }

            is_mention = MapSet.member?(gold_mentions, {sent_idx, start_idx, end_idx})
            {span, if(is_mention, do: 1, else: 0)}
          end
        end)

      # Split positive and negative
      {positive, negative} =
        Enum.split_with(candidate_spans, fn {_span, label} -> label == 1 end)

      # Sample negative spans
      num_negative = round(length(positive) * negative_ratio)
      sampled_negative = Enum.take_random(negative, min(num_negative, length(negative)))

      positive ++ sampled_negative
    end)
  end

  @doc """
  Create antecedent training data for end-to-end coreference.

  For each mention, generates (mention, antecedent, label) triples.
  Label is 1 if antecedent is coreferent, 0 otherwise.

  ## Options

    - `:max_antecedent_distance` - Maximum distance in mentions (default: 50)
    - `:negative_antecedent_ratio` - Ratio of negative to positive (default: 1.5)

  ## Returns

  List of {mention_span, antecedent_span, label} tuples
  """
  @spec create_antecedent_data([coref_document()], keyword()) :: [{map(), map(), 0 | 1}]
  def create_antecedent_data(documents, opts \\ []) do
    max_distance = Keyword.get(opts, :max_antecedent_distance, 50)
    negative_ratio = Keyword.get(opts, :negative_antecedent_ratio, 1.5)

    Enum.flat_map(documents, fn doc ->
      # Collect all mentions with their chain IDs
      all_mentions =
        doc.chains
        |> Enum.flat_map(fn chain ->
          Enum.map(chain.mentions, fn m ->
            %{
              span: %{
                sentence_idx: m.sentence_idx,
                start_idx: m.token_idx,
                end_idx: m.token_idx + length(m.tokens) - 1,
                tokens: m.tokens
              },
              chain_id: m.chain_id
            }
          end)
        end)
        |> Enum.sort_by(fn m -> {m.span.sentence_idx, m.span.start_idx} end)

      # For each mention, find antecedents
      all_mentions
      |> Enum.with_index()
      |> Enum.flat_map(fn {mention, idx} ->
        # Get previous mentions within distance
        start_idx = max(0, idx - max_distance)
        candidates = Enum.slice(all_mentions, start_idx..(idx - 1))

        # Split into positive and negative
        {positive, negative} =
          Enum.split_with(candidates, fn ant ->
            ant.chain_id == mention.chain_id
          end)

        # Generate positive pairs
        positive_pairs =
          Enum.map(positive, fn ant ->
            {mention.span, ant.span, 1}
          end)

        # Sample negative pairs
        num_negative = round(length(positive_pairs) * negative_ratio)

        negative_pairs =
          negative
          |> Enum.take_random(min(num_negative, length(negative)))
          |> Enum.map(fn ant -> {mention.span, ant.span, 0} end)

        positive_pairs ++ negative_pairs
      end)
    end)
  end
end
