defmodule Nasty.Language.Catalan.Tokenizer do
  @moduledoc """
  Tokenizer for Catalan text using NimbleParsec.

  ## Catalan-Specific Features

  - **Interpunct (l·l)**: Kept as single token
  - **Apostrophe contractions**: l', d', s', n', m', t'
  - **Article contractions**: del, al, pel
  - **Catalan diacritics**: à, è, é, í, ï, ò, ó, ú, ü, ç
  """

  import NimbleParsec
  alias Nasty.AST.{Node, Token}

  # Whitespace
  whitespace =
    choice([string(" "), string("\t"), string("\n"), string("\r")])
    |> times(min: 1)
    |> ignore()

  # Punctuation
  sentence_end = choice([string("."), string("!"), string("?")]) |> unwrap_and_tag(:sentence_end)
  comma = string(",") |> unwrap_and_tag(:punct)
  semicolon = string(";") |> unwrap_and_tag(:punct)
  colon = string(":") |> unwrap_and_tag(:punct)

  punctuation = choice([sentence_end, comma, semicolon, colon, string("("), string(")")]) |> unwrap_and_tag(:punct)

  # Numbers
  number =
    ascii_string([?0..?9], min: 1)
    |> optional(choice([string(","), string(".")]) |> concat(ascii_string([?0..?9], min: 1)))
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:number)

  # Catalan diacritics
  catalan_accented = [0x00E0, 0x00E8, 0x00E9, 0x00ED, 0x00EF, 0x00F2, 0x00F3, 0x00FA, 0x00FC, 0x00E7,
                       0x00C0, 0x00C8, 0x00C9, 0x00CD, 0x00CF, 0x00D2, 0x00D3, 0x00DA, 0x00DC, 0x00C7]
  
  # Interpunct
  interpunct = [0x00B7]

  # Apostrophe contractions
  apostrophe_contraction =
    choice([
      string("l'"), string("L'"), string("d'"), string("D'"),
      string("s'"), string("S'"), string("n'"), string("N'"),
      string("m'"), string("M'"), string("t'"), string("T'")
    ])
    |> lookahead(utf8_string([?a..?z, ?A..?Z] ++ catalan_accented, 1))
    |> unwrap_and_tag(:apostrophe_contraction)

  # Article contractions
  article_contraction =
    choice([string("del"), string("al"), string("pel"), string("Del"), string("Al"), string("Pel")])
    |> lookahead_not(utf8_string([?a..?z, ?A..?Z] ++ catalan_accented, 1))
    |> unwrap_and_tag(:contraction)

  # Interpunct words (l·l)
  interpunct_word =
    utf8_string([?a..?z, ?A..?Z] ++ catalan_accented, min: 1)
    |> utf8_string(interpunct, 1)
    |> utf8_string([?a..?z, ?A..?Z] ++ catalan_accented, min: 1)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:interpunct_word)

  # Regular words
  word = utf8_string([?a..?z, ?A..?Z] ++ catalan_accented, min: 1) |> unwrap_and_tag(:word)

  # Token
  token = choice([apostrophe_contraction, article_contraction, interpunct_word, number, word, punctuation])

  # Text
  text = repeat(token |> optional(whitespace))

  defparsec(:parse_text, text, inline: true)

  @spec tokenize(String.t(), keyword()) :: {:ok, [Token.t()]} | {:error, term()}
  def tokenize(text, _opts \\ []) do
    text = String.normalize(text, :nfc)

    if String.trim(text) == "" do
      {:ok, []}
    else
      case parse_text(text) do
        {:ok, parsed_tokens, "", %{}, {line, col}, byte_offset} ->
          tokens = build_tokens(parsed_tokens, {line, col}, byte_offset)
          {:ok, tokens}

        {:ok, _parsed, rest, %{}, {line, col}, byte_offset} ->
          {:error, {:parse_incomplete, "Could not parse at line #{line}, col #{col}: #{inspect(rest)}"}}

        {:error, reason, _rest, %{}, {line, col}, byte_offset} ->
          {:error, {:parse_failed, reason, line, col, byte_offset}}
      end
    end
  end

  defp build_tokens(parsed_tokens, _end_pos, _end_offset) do
    {tokens, _byte_pos, _line, _col} =
      Enum.reduce(parsed_tokens, {[], 0, 1, 0}, fn
        # Handle nested tags from choice combinators (e.g., {:punct, {:sentence_end, "."}})
        {outer_tag, {inner_tag, token_text}}, {acc_tokens, byte_pos, line, col} when is_binary(token_text) ->
          token_bytes = byte_size(token_text)
          start_offset = byte_pos
          end_offset = byte_pos + token_bytes
          
          span = Node.make_span({line, col}, start_offset, {line, col + String.length(token_text)}, end_offset)
          
          # Use inner tag for more specificity
          tag = inner_tag || outer_tag
          token = %Token{text: token_text, pos_tag: tag_to_pos(tag), language: :ca, span: span}
          
          new_col = col + String.length(token_text)
          {[token | acc_tokens], end_offset, line, new_col}
        
        # Handle simple tags
        {tag, token_text}, {acc_tokens, byte_pos, line, col} when is_binary(token_text) ->
          token_bytes = byte_size(token_text)
          start_offset = byte_pos
          end_offset = byte_pos + token_bytes
          
          span = Node.make_span({line, col}, start_offset, {line, col + String.length(token_text)}, end_offset)
          
          token = %Token{text: token_text, pos_tag: tag_to_pos(tag), language: :ca, span: span}
          
          new_col = col + String.length(token_text)
          {[token | acc_tokens], end_offset, line, new_col}
      end)

    Enum.reverse(tokens)
  end

  defp tag_to_pos(:number), do: :num
  defp tag_to_pos(:punct), do: :punct
  defp tag_to_pos(:sentence_end), do: :punct
  defp tag_to_pos(_), do: nil
end
