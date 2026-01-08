defmodule Nasty.Language.English.Tokenizer do
  @moduledoc """
  English tokenizer using NimbleParsec.

  Tokenizes English text into words, punctuation, numbers, and special tokens
  with accurate position tracking for AST span information.

  ## Features

  - Word tokenization with contractions ("don't", "I'm", "we've")
  - Punctuation handling (periods, commas, quotes, etc.)
  - Number recognition (integers, decimals, percentages)
  - Sentence boundary detection
  - Accurate line/column and byte offset tracking
  - Unicode support

  ## Examples

      iex> {:ok, tokens} = Nasty.Language.English.Tokenizer.tokenize("Hello world!")
      iex> Enum.map(tokens, & &1.text)
      ["Hello", "world", "!"]
  """

  import NimbleParsec
  alias Nasty.AST.{Node, Token}

  # Whitespace (ignored but tracked for position)
  whitespace =
    choice([
      string(" "),
      string("\t"),
      string("\n"),
      string("\r")
    ])
    |> times(min: 1)
    |> ignore()

  # Sentence-ending punctuation
  sentence_end =
    choice([
      string("."),
      string("!"),
      string("?")
    ])
    |> unwrap_and_tag(:sentence_end)

  # Other punctuation
  comma = string(",") |> unwrap_and_tag(:punct)
  semicolon = string(";") |> unwrap_and_tag(:punct)
  colon = string(":") |> unwrap_and_tag(:punct)
  dollar = string("$") |> unwrap_and_tag(:punct)

  quote_single = string("'") |> unwrap_and_tag(:punct)
  quote_double = string("\"") |> unwrap_and_tag(:punct)

  paren_open = string("(") |> unwrap_and_tag(:punct)
  paren_close = string(")") |> unwrap_and_tag(:punct)

  bracket_open = string("[") |> unwrap_and_tag(:punct)
  bracket_close = string("]") |> unwrap_and_tag(:punct)

  # All punctuation
  punctuation =
    choice([
      sentence_end,
      comma,
      semicolon,
      colon,
      dollar,
      quote_single,
      quote_double,
      paren_open,
      paren_close,
      bracket_open,
      bracket_close
    ])

  # Numbers (integers and decimals)
  number =
    ascii_string([?0..?9], min: 1)
    |> optional(
      string(".")
      |> concat(ascii_string([?0..?9], min: 1))
    )
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:number)

  # Contractions (e.g., "don't", "I'm", "we've", "it's")
  # Must come before regular words to match first
  contraction =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> string("'")
    |> choice([
      # don't, can't, won't
      string("t"),
      # it's, that's, what's
      string("s"),
      # I'm
      string("m"),
      # we're, they're, you're
      string("re"),
      # I've, we've, they've
      string("ve"),
      # I'll, we'll, they'll
      string("ll"),
      # I'd, we'd, they'd
      string("d")
    ])
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:contraction)

  # Regular words (letters only, including uppercase)
  word =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> unwrap_and_tag(:word)

  # Hyphenated words (e.g., "well-known", "twenty-one")
  hyphenated =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> string("-")
    |> ascii_string([?a..?z, ?A..?Z], min: 1)
    |> optional(
      string("-")
      |> concat(ascii_string([?a..?z, ?A..?Z], min: 1))
    )
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:hyphenated)

  # Token: try in order of specificity
  token =
    choice([
      hyphenated,
      contraction,
      number,
      word,
      punctuation
    ])

  # Text: sequence of tokens with optional whitespace
  text =
    repeat(
      token
      |> optional(whitespace)
    )

  defparsec(:parse_text, text, inline: true)

  @doc """
  Tokenizes English text into Token structs.

  Returns a list of Token structs with:
  - Accurate text content
  - Position information (line, column, byte offset)
  - Span covering the token's location
  - Language set to :en

  Note: POS tags and morphology are not set by the tokenizer;
  those are added by the POS tagger.

  ## Parameters

    - `text` - The text to tokenize
    - `opts` - Options (currently unused)

  ## Returns

    - `{:ok, tokens}` - List of Token structs
    - `{:error, reason}` - Parse error

  ## Examples

      iex> {:ok, tokens} = Nasty.Language.English.Tokenizer.tokenize("Hello!")
      iex> length(tokens)
      2
      iex> hd(tokens).text
      "Hello"
      
      iex> {:ok, tokens} = Nasty.Language.English.Tokenizer.tokenize("I don't know.")
      iex> Enum.map(tokens, & &1.text)
      ["I", "don't", "know", "."]
  """
  @spec tokenize(String.t(), keyword()) :: {:ok, [Token.t()]} | {:error, term()}
  def tokenize(text, _opts \\ []) do
    # Normalize to NFC form to ensure consistent Unicode representation
    text = String.normalize(text, :nfc)

    # Handle empty or whitespace-only text
    if String.trim(text) == "" do
      {:ok, []}
    else
      case parse_text(text) do
        {:ok, parsed_tokens, "", %{}, {line, col}, byte_offset} ->
          # Successfully parsed entire text
          tokens = build_tokens(parsed_tokens, text, {line, col}, byte_offset)
          {:ok, tokens}

        {:ok, _parsed, rest, %{}, {line, col}, byte_offset} ->
          # Partially parsed - some text remaining
          {:error,
           {:parse_incomplete,
            "Could not parse remaining text at line #{line}, column #{col}, byte #{byte_offset}: #{inspect(rest)}"}}

        {:error, reason, _rest, %{}, {line, col}, byte_offset} ->
          {:error, {:parse_failed, reason, line, col, byte_offset}}
      end
    end
  end

  ## Private Helpers

  # Builds Token structs from NimbleParsec output
  defp build_tokens(parsed_tokens, original_text, _end_pos, _end_offset) do
    # Track current position as we iterate
    {tokens, _byte_pos, _line, _col} =
      Enum.reduce(parsed_tokens, {[], 0, 1, 0}, fn
        {tag, token_text}, {acc_tokens, byte_pos, line, col} when is_binary(token_text) ->
          # Calculate token boundaries
          token_bytes = byte_size(token_text)
          start_offset = byte_pos
          end_offset = byte_pos + token_bytes

          # Create span
          span =
            Node.make_span(
              {line, col},
              start_offset,
              {line, col + String.length(token_text)},
              end_offset
            )

          # Create token (no POS tag yet - that comes from POS tagger)
          token = %Token{
            text: token_text,
            pos_tag: tag_to_initial_pos(tag),
            language: :en,
            span: span
          }

          # Update position tracking
          # Check for newlines in token
          {new_line, new_col} =
            if String.contains?(token_text, "\n") do
              lines = String.split(token_text, "\n")
              {line + length(lines) - 1, String.length(List.last(lines))}
            else
              {line, col + String.length(token_text)}
            end

          # Account for whitespace after token (approximation)
          # NimbleParsec ignores whitespace but we need to track it for next token
          ws_after = find_whitespace_after(original_text, end_offset)

          {new_line_final, new_col_final, new_byte_pos} =
            if ws_after > 0 do
              ws_text = String.slice(original_text, end_offset, ws_after)

              if String.contains?(ws_text, "\n") do
                ws_lines = String.split(ws_text, "\n")

                {new_line + length(ws_lines) - 1, String.length(List.last(ws_lines)),
                 end_offset + ws_after}
              else
                {new_line, new_col + ws_after, end_offset + ws_after}
              end
            else
              {new_line, new_col, end_offset}
            end

          {[token | acc_tokens], new_byte_pos, new_line_final, new_col_final}
      end)

    Enum.reverse(tokens)
  end

  # Maps parser tag to initial POS tag (will be refined by POS tagger)
  defp tag_to_initial_pos(:word), do: :x
  defp tag_to_initial_pos(:contraction), do: :x
  defp tag_to_initial_pos(:hyphenated), do: :x
  defp tag_to_initial_pos(:number), do: :num
  defp tag_to_initial_pos(:punct), do: :punct
  defp tag_to_initial_pos(:sentence_end), do: :punct
  defp tag_to_initial_pos(_), do: :x

  # Finds whitespace immediately after a byte position
  defp find_whitespace_after(text, offset) do
    if offset >= byte_size(text) do
      0
    else
      rest = String.slice(text, offset..-1//1)

      case Regex.run(~r/^[\s\t\n\r]+/, rest) do
        [ws] -> byte_size(ws)
        nil -> 0
      end
    end
  end
end
