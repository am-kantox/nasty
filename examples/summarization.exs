#!/usr/bin/env elixir

# Summarization Example
#
# This script demonstrates the text summarization capabilities of the Nasty library.
# It shows both greedy and MMR (Maximal Marginal Relevance) selection methods.

# Add the library to the path
Mix.install([{:nasty, path: Path.expand("..", __DIR__)}])

alias Nasty.Language.English

# Sample text for summarization
sample_text = """
Natural language processing is a subfield of artificial intelligence that focuses on the
interaction between computers and human language. The goal of NLP is to enable computers
to understand, interpret, and generate human language in a valuable way.

One of the fundamental challenges in NLP is ambiguity. Natural language is inherently
ambiguous at multiple levels including lexical, syntactic, and semantic levels. For example,
the word "bank" can refer to a financial institution or the side of a river. Importantly,
context is crucial for resolving such ambiguities.

Machine learning has revolutionized NLP in recent years. Deep learning models, particularly
transformer architectures like BERT and GPT, have achieved remarkable performance on various
NLP tasks. These models can learn complex patterns from large amounts of text data.

However, there are still significant challenges in NLP. Understanding context, handling rare
words, and capturing long-range dependencies remain difficult. In conclusion, while great
progress has been made, there is still much work to be done in making computers truly
understand human language.
"""

IO.puts("=" <> String.duplicate("=", 78))
IO.puts("Nasty: Text Summarization Example")
IO.puts("=" <> String.duplicate("=", 78))
IO.puts("")

# Parse the text
IO.puts("Parsing document...")
{:ok, tokens} = English.tokenize(sample_text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, document} = English.parse(tagged)

sentence_count = document.paragraphs |> Enum.flat_map(& &1.sentences) |> length()
IO.puts("Document has #{sentence_count} sentences")
IO.puts("")

# Example 1: Greedy summarization with 30% compression
IO.puts("Example 1: Greedy Summarization (30% compression)")
IO.puts(String.duplicate("-", 79))

summary_greedy = English.summarize(document, ratio: 0.3, method: :greedy)

IO.puts("Selected #{length(summary_greedy)} sentences:")
IO.puts("")

summary_greedy
|> Enum.with_index(1)
|> Enum.each(fn {sentence, idx} ->
  # Extract text from sentence
  tokens =
    sentence
    |> Nasty.AST.Sentence.all_tokens()
    |> Enum.map(& &1.text)
    |> Enum.join(" ")

  IO.puts("#{idx}. #{tokens}")
  IO.puts("")
end)

# Example 2: Greedy summarization with fixed sentence count
IO.puts("")
IO.puts("Example 2: Greedy Summarization (max 3 sentences)")
IO.puts(String.duplicate("-", 79))

summary_fixed = English.summarize(document, max_sentences: 3, method: :greedy)

IO.puts("Selected #{length(summary_fixed)} sentences:")
IO.puts("")

summary_fixed
|> Enum.with_index(1)
|> Enum.each(fn {sentence, idx} ->
  tokens =
    sentence
    |> Nasty.AST.Sentence.all_tokens()
    |> Enum.map(& &1.text)
    |> Enum.join(" ")

  IO.puts("#{idx}. #{tokens}")
  IO.puts("")
end)

# Example 3: MMR summarization to reduce redundancy
IO.puts("")
IO.puts("Example 3: MMR Summarization (max 3 sentences, lambda=0.5)")
IO.puts(String.duplicate("-", 79))
IO.puts("MMR balances relevance and diversity to avoid redundant sentences")
IO.puts("")

summary_mmr = English.summarize(document, max_sentences: 3, method: :mmr, mmr_lambda: 0.5)

IO.puts("Selected #{length(summary_mmr)} sentences:")
IO.puts("")

summary_mmr
|> Enum.with_index(1)
|> Enum.each(fn {sentence, idx} ->
  tokens =
    sentence
    |> Nasty.AST.Sentence.all_tokens()
    |> Enum.map(& &1.text)
    |> Enum.join(" ")

  IO.puts("#{idx}. #{tokens}")
  IO.puts("")
end)

# Example 4: MMR with different lambda values
IO.puts("")
IO.puts("Example 4: Comparing MMR with Different Lambda Values")
IO.puts(String.duplicate("-", 79))
IO.puts("High lambda (0.9) favors relevance, low lambda (0.1) favors diversity")
IO.puts("")

IO.puts("High Lambda (0.9) - Favors Relevance:")
summary_high_lambda = English.summarize(document, max_sentences: 2, method: :mmr, mmr_lambda: 0.9)
Enum.each(summary_high_lambda, fn sentence ->
  tokens =
    sentence
    |> Nasty.AST.Sentence.all_tokens()
    |> Enum.map(& &1.text)
    |> Enum.join(" ")

  IO.puts("- #{tokens}")
end)

IO.puts("")
IO.puts("Low Lambda (0.1) - Favors Diversity:")
summary_low_lambda = English.summarize(document, max_sentences: 2, method: :mmr, mmr_lambda: 0.1)
Enum.each(summary_low_lambda, fn sentence ->
  tokens =
    sentence
    |> Nasty.AST.Sentence.all_tokens()
    |> Enum.map(& &1.text)
    |> Enum.join(" ")

  IO.puts("- #{tokens}")
end)

IO.puts("")
IO.puts("=" <> String.duplicate("=", 78))
IO.puts("Summarization Features:")
IO.puts("- Position scoring (early sentences weighted higher)")
IO.puts("- Entity density (sentences with named entities score higher)")
IO.puts("- Discourse markers ('in conclusion', 'importantly', etc.)")
IO.puts("- Keyword frequency (TF scoring)")
IO.puts("- Sentence length preference (moderate length preferred)")
IO.puts("- MMR for redundancy reduction")
IO.puts("=" <> String.duplicate("=", 78))
