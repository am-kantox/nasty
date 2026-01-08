#!/usr/bin/env elixir

# Spanish NLP Example
# Demonstrates Spanish language processing capabilities in Nasty
# Run with: mix run examples/spanish_example.exs

alias Nasty.Language.Spanish

IO.puts("\n=== Nasty Spanish NLP Example ===\n")

# Example 1: Basic Tokenization
IO.puts("1. Tokenization")
IO.puts("   Text: \"¿Cómo estás? ¡Muy bien!\"")

{:ok, tokens} = Spanish.tokenize("¿Cómo estás? ¡Muy bien!")
token_texts = Enum.map(tokens, & &1.text)
IO.puts("   Tokens: #{inspect(token_texts)}\n")

# Example 2: POS Tagging
IO.puts("2. Part-of-Speech Tagging")
text = "El gato duerme en el sofá."
IO.puts("   Text: \"#{text}\"")

{:ok, tokens} = Spanish.tokenize(text)
{:ok, tagged} = Spanish.tag_pos(tokens)

Enum.each(tagged, fn token ->
  IO.puts("   #{token.text}: #{token.pos_tag}")
end)

IO.puts("")

# Example 3: Contractions
IO.puts("3. Spanish Contractions (del, al)")
text = "Voy del mercado al parque."
IO.puts("   Text: \"#{text}\"")

{:ok, tokens} = Spanish.tokenize(text)
token_texts = Enum.map(tokens, & &1.text)
IO.puts("   Tokens: #{inspect(token_texts)}\n")

# Example 4: Full Parsing
IO.puts("4. Complete Parsing")
text = "El niño juega en el jardín."
IO.puts("   Text: \"#{text}\"")

{:ok, tokens} = Spanish.tokenize(text)
{:ok, tagged} = Spanish.tag_pos(tokens)
{:ok, document} = Spanish.parse(tagged)

IO.puts("   Language: #{document.language}")
IO.puts("   Paragraphs: #{length(document.paragraphs)}")
IO.puts("   Sentences: #{document.metadata.sentence_count}\n")

# Example 5: Rendering
IO.puts("5. AST → Text Rendering")
text = "La familia viaja a España"
IO.puts("   Original: \"#{text}\"")

{:ok, tokens} = Spanish.tokenize(text)
{:ok, tagged} = Spanish.tag_pos(tokens)
{:ok, document} = Spanish.parse(tagged)
{:ok, rendered} = Spanish.render(document)

IO.puts("   Rendered: \"#{String.trim(rendered)}\"\n")

# Example 6: Language Metadata
IO.puts("6. Language Information")
metadata = Spanish.metadata()
IO.puts("   Name: #{metadata.name}")
IO.puts("   Native Name: #{metadata.native_name}")
IO.puts("   ISO 639-1: #{metadata.iso_639_1}")
IO.puts("   Family: #{metadata.family}")
IO.puts("   Branch: #{metadata.branch}")
IO.puts("   Features: #{inspect(metadata.features)}\n")

# Example 7: Accented Characters
IO.puts("7. Spanish Accented Characters")
text = "José María habló con Ángel sobre la niña."
IO.puts("   Text: \"#{text}\"")

{:ok, tokens} = Spanish.tokenize(text)
{:ok, tagged} = Spanish.tag_pos(tokens)

proper_nouns = Enum.filter(tagged, &(&1.pos_tag == :propn))
IO.puts("   Proper Nouns: #{Enum.map(proper_nouns, & &1.text) |> Enum.join(", ")}\n")

IO.puts("=== Example Complete ===\n")
