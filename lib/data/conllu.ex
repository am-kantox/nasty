defmodule Nasty.Data.CoNLLU do
  @moduledoc """
  Parser for CoNLL-U format used by Universal Dependencies.

  ## CoNLL-U Format

  CoNLL-U is a tab-separated format with 10 columns:
  1. ID - Word index
  2. FORM - Word form
  3. LEMMA - Lemma
  4. UPOS - Universal POS tag
  5. XPOS - Language-specific POS tag
  6. FEATS - Morphological features
  7. HEAD - Head of dependency relation
  8. DEPREL - Dependency relation
  9. DEPS - Enhanced dependencies
  10. MISC - Miscellaneous annotations

  Lines starting with # are comments (sentence-level metadata).
  Blank lines separate sentences.

  ## Examples

      # Parse a file
      {:ok, sentences} = CoNLLU.parse_file("en_ewt-ud-train.conllu")

      # Parse a string
      conllu_text = \"\"\"
      # sent_id = 1
      # text = The cat sat.
      1\\tThe\\tthe\\tDET\\t...
      2\\tcat\\tcat\\tNOUN\\t...
      3\\tsat\\tsit\\tVERB\\t...
      \"\"\"
      {:ok, sentences} = CoNLLU.parse_string(conllu_text)
  """

  @type token :: %{
          id: pos_integer(),
          form: String.t(),
          lemma: String.t(),
          upos: atom(),
          xpos: String.t() | nil,
          feats: map(),
          head: non_neg_integer(),
          deprel: String.t(),
          deps: String.t() | nil,
          misc: map()
        }

  @type sentence :: %{
          id: String.t() | nil,
          text: String.t() | nil,
          tokens: [token()],
          metadata: map()
        }

  @doc """
  Parse a CoNLL-U file.

  ## Parameters

    - `path` - Path to the .conllu file

  ## Returns

    - `{:ok, sentences}` - List of parsed sentences
    - `{:error, reason}` - Parse error
  """
  @spec parse_file(Path.t()) :: {:ok, [sentence()]} | {:error, term()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, content} -> parse_string(content)
      {:error, reason} -> {:error, {:file_read_failed, reason}}
    end
  end

  @doc """
  Parse a CoNLL-U formatted string.

  ## Parameters

    - `content` - CoNLL-U formatted text

  ## Returns

    - `{:ok, sentences}` - List of parsed sentences
    - `{:error, reason}` - Parse error
  """
  @spec parse_string(String.t()) :: {:ok, [sentence()]} | {:error, term()}
  def parse_string(content) do
    try do
      sentences =
        content
        |> String.split("\n\n", trim: true)
        |> Enum.map(&parse_sentence/1)
        |> Enum.reject(&is_nil/1)

      {:ok, sentences}
    rescue
      e -> {:error, {:parse_failed, e}}
    end
  end

  @doc """
  Convert parsed sentences back to CoNLL-U format.

  ## Parameters

    - `sentences` - List of sentence maps

  ## Returns

    - CoNLL-U formatted string
  """
  @spec format([sentence()]) :: String.t()
  def format(sentences) do
    sentences
    |> Enum.map(&sentence_to_string/1)
    |> Enum.join("\n\n")
  end

  ## Private Functions

  defp parse_sentence(text) do
    lines = String.split(text, "\n", trim: true)

    {metadata, token_lines} = Enum.split_with(lines, &String.starts_with?(&1, "#"))

    metadata_map = parse_metadata(metadata)
    tokens = Enum.map(token_lines, &parse_token_line/1) |> Enum.reject(&is_nil/1)

    if Enum.empty?(tokens) do
      nil
    else
      %{
        id: Map.get(metadata_map, "sent_id"),
        text: Map.get(metadata_map, "text"),
        tokens: tokens,
        metadata: metadata_map
      }
    end
  end

  defp parse_metadata(metadata_lines) do
    metadata_lines
    |> Enum.map(fn line ->
      # Remove leading '# '
      line = String.trim_leading(line, "# ")

      case String.split(line, " = ", parts: 2) do
        [key, value] -> {key, value}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp parse_token_line(line) do
    case String.split(line, "\t") do
      [id, form, lemma, upos, xpos, feats, head, deprel, deps, misc] ->
        # Skip multiword tokens (e.g., "1-2")
        if String.contains?(id, "-") or String.contains?(id, ".") do
          nil
        else
          %{
            id: String.to_integer(id),
            form: form,
            lemma: lemma,
            upos: parse_upos(upos),
            xpos: if(xpos == "_", do: nil, else: xpos),
            feats: parse_features(feats),
            head: String.to_integer(head),
            deprel: deprel,
            deps: if(deps == "_", do: nil, else: deps),
            misc: parse_misc(misc)
          }
        end

      _ ->
        nil
    end
  end

  defp parse_upos("_"), do: nil

  defp parse_upos(upos) do
    # Map UD tags to our internal tags
    case String.downcase(upos) do
      "noun" -> :noun
      "propn" -> :propn
      "verb" -> :verb
      "adj" -> :adj
      "adv" -> :adv
      "det" -> :det
      "adp" -> :adp
      "pron" -> :pron
      "aux" -> :aux
      "cconj" -> :cconj
      "sconj" -> :sconj
      "part" -> :part
      "num" -> :num
      "punct" -> :punct
      "intj" -> :intj
      "sym" -> :sym
      "x" -> :x
      _ -> String.to_atom(String.downcase(upos))
    end
  end

  defp parse_features("_"), do: %{}

  defp parse_features(feats) do
    feats
    |> String.split("|")
    |> Enum.map(fn feat ->
      case String.split(feat, "=") do
        [key, value] -> {String.to_atom(key), value}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp parse_misc("_"), do: %{}

  defp parse_misc(misc) do
    misc
    |> String.split("|")
    |> Enum.map(fn item ->
      case String.split(item, "=") do
        [key, value] -> {key, value}
        [key] -> {key, true}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp sentence_to_string(sentence) do
    metadata_lines =
      sentence.metadata
      |> Enum.map(fn {key, value} -> "# #{key} = #{value}" end)
      |> Enum.join("\n")

    token_lines =
      sentence.tokens
      |> Enum.map(&token_to_string/1)
      |> Enum.join("\n")

    metadata_lines <> "\n" <> token_lines
  end

  defp token_to_string(token) do
    [
      to_string(token.id),
      token.form,
      token.lemma,
      upos_to_string(token.upos),
      token.xpos || "_",
      features_to_string(token.feats),
      to_string(token.head),
      token.deprel,
      token.deps || "_",
      misc_to_string(token.misc)
    ]
    |> Enum.join("\t")
  end

  defp upos_to_string(nil), do: "_"

  defp upos_to_string(upos) when is_atom(upos) do
    upos |> Atom.to_string() |> String.upcase()
  end

  defp features_to_string(feats) when map_size(feats) == 0, do: "_"

  defp features_to_string(feats) do
    feats
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
    |> Enum.sort()
    |> Enum.join("|")
  end

  defp misc_to_string(misc) when map_size(misc) == 0, do: "_"

  defp misc_to_string(misc) do
    misc
    |> Enum.map(fn
      {key, true} -> key
      {key, value} -> "#{key}=#{value}"
    end)
    |> Enum.sort()
    |> Enum.join("|")
  end
end
