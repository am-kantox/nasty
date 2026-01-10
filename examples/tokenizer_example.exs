# Example: Simple English Tokenizer with NimbleParsec
#
# This demonstrates the NimbleParsec approach for Phase 2 tokenization.
# Run with: mix run examples/tokenizer_example.exs

defmodule Nasty.Examples.SimpleTokenizer do
  @moduledoc """
  A simple English tokenizer using NimbleParsec to demonstrate the approach.
  
  This is a simplified version showing the key concepts. The full implementation
  will handle more edge cases and linguistic phenomena.
  """
  
  import NimbleParsec

  # Whitespace (ignored)
  whitespace = ascii_string([?\s, ?\t, ?\n, ?\r], min: 1)

  # Punctuation marks
  sentence_end = 
    choice([string("."), string("!"), string("?")])
    |> unwrap_and_tag(:sentence_end)

  comma = string(",") |> replace(:comma) |> unwrap_and_tag(:punct)
  
  semicolon = string(";") |> replace(:semicolon) |> unwrap_and_tag(:punct)
  
  punctuation = choice([sentence_end, comma, semicolon])

  # Words (simple version - alphanumeric only)
  word = 
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> unwrap_and_tag(:word)

  # Contractions (e.g., "don't", "it's")
  contraction =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> string("'")
    |> ascii_string([?a..?z, ?A..?Z], min: 1)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:contraction)

  # Token: try contraction first, then word, then punctuation
  token = 
    choice([
      contraction,
      word,
      punctuation
    ])

  # Sentence: tokens separated by optional whitespace
  sentence =
    repeat(
      token
      |> optional(ignore(whitespace))
    )

  # Document: multiple sentences
  defparsec :parse_text, sentence

  @doc """
  Tokenize English text into a list of tagged tokens.
  
  ## Examples
  
      iex> tokenize("Hello world.")
      {:ok, [word: "Hello", word: "world", sentence_end: "."], "", %{}, {1, 0}, 12}
      
      iex> tokenize("I don't know.")
      {:ok, [word: "I", contraction: "don't", word: "know", sentence_end: "."], "", %{}, {1, 0}, 13}
  """
  def tokenize(text) do
    parse_text(text)
  end
end

# Demo
IO.puts("Nasty Tokenizer Example with NimbleParsec\n")
IO.puts("=" |> String.duplicate(50))

alias Nasty.Examples.SimpleTokenizer

# Example 1: Simple sentence
text1 = "The cat sat on the mat."
{:ok, tokens1, _, _, _, _} = SimpleTokenizer.tokenize(text1)
IO.puts("\nInput:  #{inspect(text1)}")
IO.puts("Tokens: #{inspect(tokens1)}")

# Example 2: Sentence with contraction
text2 = "I don't understand this."
{:ok, tokens2, _, _, _, _} = SimpleTokenizer.tokenize(text2)
IO.puts("\nInput:  #{inspect(text2)}")
IO.puts("Tokens: #{inspect(tokens2)}")

# Example 3: Multiple punctuation
text3 = "Hello, world! How are you?"
{:ok, tokens3, _, _, _, _} = SimpleTokenizer.tokenize(text3)
IO.puts("\nInput:  #{inspect(text3)}")
IO.puts("Tokens: #{inspect(tokens3)}")

IO.puts("\n" <> ("=" |> String.duplicate(50)))
IO.puts("\nKey Benefits of NimbleParsec:")
IO.puts("  • Composable grammar rules")
IO.puts("  • Automatic position tracking")
IO.puts("  • Compile-time optimization")
IO.puts("  • Clean, declarative syntax")
IO.puts("  • Built-in backtracking for ambiguity")
