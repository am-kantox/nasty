defmodule Nasty.Language.Spanish.Tokenizer do
  @moduledoc """
  Spanish tokenizer using NimbleParsec.

  Tokenizes Spanish text into words, punctuation, numbers, and special tokens
  with accurate position tracking for AST span information.

  ## Spanish-Specific Features

  - Inverted punctuation: ¿?, ¡!
  - Guillemets: «», ‹›
  - Contractions: del, al, del
  - Clitic pronouns: dámelo, dáselo, cómetelo
  - Accented characters: á, é, í, ó, ú, ñ, ü
  - Abbreviations: Sr., Sra., Dr., etc.

  ## Examples

      iex> {:ok, tokens} = Spanish.Tokenizer.tokenize("¡Hola mundo!")
      iex> Enum.map(tokens, & &1.text)
      ["¡", "Hola", "mundo", "!"]

      iex> {:ok, tokens} = Spanish.Tokenizer.tokenize("¿Cómo estás?")
      iex> Enum.map(tokens, & &1.text)
      ["¿", "Cómo", "estás", "?"]
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

  # Spanish inverted punctuation (opening)
  inverted_question = string("¿") |> unwrap_and_tag(:punct)
  inverted_exclamation = string("¡") |> unwrap_and_tag(:punct)

  # Sentence-ending punctuation
  sentence_end =
    choice([
      string("."),
      string("!"),
      string("?")
    ])
    |> unwrap_and_tag(:sentence_end)

  # Spanish guillemets (quotation marks)
  guillemet_open = string("«") |> unwrap_and_tag(:punct)
  guillemet_close = string("»") |> unwrap_and_tag(:punct)
  guillemet_single_open = string("‹") |> unwrap_and_tag(:punct)
  guillemet_single_close = string("›") |> unwrap_and_tag(:punct)

  # Other punctuation
  comma = string(",") |> unwrap_and_tag(:punct)
  semicolon = string(";") |> unwrap_and_tag(:punct)
  colon = string(":") |> unwrap_and_tag(:punct)
  dollar = string("$") |> unwrap_and_tag(:punct)
  euro = string("€") |> unwrap_and_tag(:punct)

  quote_single = string("'") |> unwrap_and_tag(:punct)
  quote_double = string("\"") |> unwrap_and_tag(:punct)

  paren_open = string("(") |> unwrap_and_tag(:punct)
  paren_close = string(")") |> unwrap_and_tag(:punct)

  bracket_open = string("[") |> unwrap_and_tag(:punct)
  bracket_close = string("]") |> unwrap_and_tag(:punct)

  hyphen = string("-") |> unwrap_and_tag(:punct)
  dash = string("—") |> unwrap_and_tag(:punct)

  # All punctuation (order matters - longer matches first)
  punctuation =
    choice([
      inverted_question,
      inverted_exclamation,
      guillemet_open,
      guillemet_close,
      guillemet_single_open,
      guillemet_single_close,
      sentence_end,
      comma,
      semicolon,
      colon,
      dollar,
      euro,
      quote_single,
      quote_double,
      paren_open,
      paren_close,
      bracket_open,
      bracket_close,
      dash,
      hyphen
    ])

  # Numbers (integers and decimals, Spanish uses comma for decimals but we support both)
  number =
    ascii_string([?0..?9], min: 1)
    |> optional(
      choice([string(","), string(".")])
      |> concat(ascii_string([?0..?9], min: 1))
    )
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:number)

  # Spanish accented characters ranges
  # á é í ó ú ñ ü Á É Í Ó Ú Ñ Ü
  spanish_accented = [
    # á é í ó ú
    0x00E1,
    0x00E9,
    0x00ED,
    0x00F3,
    0x00FA,
    # ñ
    0x00F1,
    # ü
    0x00FC,
    # Á É Í Ó Ú
    0x00C1,
    0x00C9,
    0x00CD,
    0x00D3,
    0x00DA,
    # Ñ
    0x00D1,
    # Ü
    0x00DC
  ]

  # Spanish contractions (must match before regular words)
  # del = de + el, al = a + el
  # Note: These are matched with word boundaries - must not be followed by letters
  contraction =
    choice([
      string("del") |> lookahead_not(utf8_string([?a..?z, ?A..?Z] ++ spanish_accented, 1)),
      string("al") |> lookahead_not(utf8_string([?a..?z, ?A..?Z] ++ spanish_accented, 1)),
      string("Del") |> lookahead_not(utf8_string([?a..?z, ?A..?Z] ++ spanish_accented, 1)),
      string("Al") |> lookahead_not(utf8_string([?a..?z, ?A..?Z] ++ spanish_accented, 1))
    ])
    |> unwrap_and_tag(:contraction)

  # Spanish words with clitic pronouns attached
  # Examples: dámelo, dáselo, cómetelo, házmelo
  # Pattern: verb + 1-3 clitics (me, te, se, lo, la, le, les, los, las, nos, os)
  clitic =
    utf8_string(
      [?a..?z, ?A..?Z] ++ spanish_accented,
      min: 2
    )
    |> choice([
      # Three clitics (rare but possible)
      string("me")
      |> string("lo")
      |> string("s"),
      string("te")
      |> string("la")
      |> string("s"),
      string("se")
      |> string("lo")
      |> string("s"),
      # Two clitics
      string("me")
      |> string("lo"),
      string("me")
      |> string("la"),
      string("me")
      |> string("las"),
      string("me")
      |> string("los"),
      string("te")
      |> string("lo"),
      string("te")
      |> string("la"),
      string("se")
      |> string("lo"),
      string("se")
      |> string("la"),
      string("se")
      |> string("las"),
      string("se")
      |> string("los"),
      string("nos")
      |> string("lo"),
      string("os")
      |> string("lo"),
      # Single clitics
      string("me"),
      string("te"),
      string("se"),
      string("lo"),
      string("la"),
      string("le"),
      string("les"),
      string("los"),
      string("las"),
      string("nos"),
      string("os")
    ])
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:clitic)

  # Abbreviations (Sr., Sra., Dr., etc.)
  abbreviation =
    choice([
      string("Sr."),
      string("Sra."),
      string("Dr."),
      string("Dra."),
      string("Prof."),
      string("Lic."),
      string("Ing."),
      string("etc."),
      string("pág."),
      string("núm."),
      string("tel.")
    ])
    |> unwrap_and_tag(:abbreviation)

  # Regular Spanish words (letters including accented characters)
  word =
    utf8_string(
      [?a..?z, ?A..?Z] ++ spanish_accented,
      min: 1
    )
    |> unwrap_and_tag(:word)

  # Hyphenated words (e.g., "bien-estar", "medio-día")
  hyphenated =
    utf8_string(
      [?a..?z, ?A..?Z] ++ spanish_accented,
      min: 1
    )
    |> string("-")
    |> utf8_string(
      [?a..?z, ?A..?Z] ++ spanish_accented,
      min: 1
    )
    |> optional(
      string("-")
      |> concat(
        utf8_string(
          [?a..?z, ?A..?Z] ++ spanish_accented,
          min: 1
        )
      )
    )
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:hyphenated)

  # Token: try in order of specificity (most specific first)
  token =
    choice([
      abbreviation,
      hyphenated,
      contraction,
      clitic,
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
  Tokenizes Spanish text into Token structs.

  Returns a list of Token structs with:
  - Accurate text content
  - Position information (line, column, byte offset)
  - Span covering the token's location
  - Language set to :es

  Note: POS tags and morphology are not set by the tokenizer;
  those are added by the POS tagger.

  ## Parameters

    - `text` - The Spanish text to tokenize
    - `opts` - Options (currently unused)

  ## Returns

    - `{:ok, tokens}` - List of Token structs
    - `{:error, reason}` - Parse error

  ## Examples

      iex> {:ok, tokens} = Spanish.Tokenizer.tokenize("¡Hola!")
      iex> length(tokens)
      3

      iex> {:ok, tokens} = Spanish.Tokenizer.tokenize("Dámelo ahora.")
      iex> Enum.map(tokens, & &1.text)
      ["Dámelo", "ahora", "."]

      iex> {:ok, tokens} = Spanish.Tokenizer.tokenize("¿Cómo estás?")
      iex> Enum.map(tokens, & &1.text)
      ["¿", "Cómo", "estás", "?"]
  """
  @spec tokenize(String.t(), keyword()) :: {:ok, [Token.t()]} | {:error, term()}
  def tokenize(text, _opts \\ []) do
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
            language: :es,
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
              # Use binary.part for byte-based slicing
              ws_text = :binary.part(original_text, end_offset, ws_after)

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
  defp tag_to_initial_pos(:clitic), do: :x
  defp tag_to_initial_pos(:hyphenated), do: :x
  defp tag_to_initial_pos(:abbreviation), do: :x
  defp tag_to_initial_pos(:number), do: :num
  defp tag_to_initial_pos(:punct), do: :punct
  defp tag_to_initial_pos(:sentence_end), do: :punct
  defp tag_to_initial_pos(_), do: :x

  # Finds whitespace immediately after a byte position
  defp find_whitespace_after(text, offset) do
    if offset >= byte_size(text) do
      0
    else
      # Use binary.part to slice by bytes, not graphemes
      rest = :binary.part(text, offset, byte_size(text) - offset)

      case Regex.run(~r/^[\s\t\n\r]+/, rest) do
        [ws] -> byte_size(ws)
        nil -> 0
      end
    end
  end
end
