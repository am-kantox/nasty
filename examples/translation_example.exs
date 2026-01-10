# Translation Example
#
# Demonstrates cross-lingual translation using Nasty's AST-based approach.
# Run with: mix run examples/translation_example.exs

alias Nasty.Translation.Translator

IO.puts("\n=== Nasty Translation System ===\n")
IO.puts("Lexicon-based, AST-driven translation")
IO.puts("Supported pairs: #{inspect(Translator.supported_pairs())}\n")

# Example 1: English to Spanish
IO.puts("--- English → Spanish ---")
examples_en_es = [
  "cat",
  "dog",
  "house",
  "water",
  "run",
  "walk",
  "big",
  "small"
]

Enum.each(examples_en_es, fn text ->
  case Translator.translate(text, :en, :es) do
    {:ok, translated} ->
      IO.puts("  #{text} → #{translated}")

    {:error, reason} ->
      IO.puts("  #{text} → ERROR: #{inspect(reason)}")
  end
end)

# Example 2: Spanish to English
IO.puts("\n--- Spanish → English ---")
examples_es_en = [
  "gato",
  "perro",
  "casa",
  "agua",
  "correr",
  "caminar",
  "grande",
  "pequeño"
]

Enum.each(examples_es_en, fn text ->
  case Translator.translate(text, :es, :en) do
    {:ok, translated} ->
      IO.puts("  #{text} → #{translated}")

    {:error, reason} ->
      IO.puts("  #{text} → ERROR: #{inspect(reason)}")
  end
end)

# Example 3: Check language pair support
IO.puts("\n--- Language Pair Support ---")

test_pairs = [
  {:en, :es},
  {:es, :en},
  {:en, :ca},
  {:en, :fr},
  {:es, :es}
]

Enum.each(test_pairs, fn {source, target} ->
  support = if Translator.supports?(source, target), do: "✓", else: "✗"
  IO.puts("  #{support} #{source} → #{target}")
end)

# Example 4: Error handling
IO.puts("\n--- Error Handling ---")

# Same language
case Translator.translate("hello", :en, :en) do
  {:error, :same_language} ->
    IO.puts("  ✓ Correctly rejects same-language translation")

  other ->
    IO.puts("  ✗ Unexpected result: #{inspect(other)}")
end

# Unsupported language
case Translator.translate("bonjour", :fr, :en) do
  {:error, {:unsupported_language, :fr}} ->
    IO.puts("  ✓ Correctly rejects unsupported language")

  other ->
    IO.puts("  ✗ Unexpected result: #{inspect(other)}")
end

# Empty string
case Translator.translate("", :en, :es) do
  {:ok, ""} ->
    IO.puts("  ✓ Correctly handles empty string")

  other ->
    IO.puts("  ✗ Unexpected result: #{inspect(other)}")
end

IO.puts("\n=== Translation Statistics ===")

# Get lexicon stats
alias Nasty.Translation.LexiconLoader

stats = LexiconLoader.stats()

IO.puts("Loaded lexicons:")

Enum.each(stats, fn {pair, info} ->
  IO.puts("  #{pair}: #{info.entries} entries")
end)

IO.puts("\nTotal language pairs: #{map_size(stats)}")
IO.puts("\n=== Example Complete ===\n")
