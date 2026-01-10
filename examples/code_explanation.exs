# Code Explanation Examples
# Demonstrates Code → Natural Language conversion
# Run with: mix run examples/code_explanation.exs

alias Nasty.Language.English

IO.puts("""
========================================
Code → Natural Language Explanation Demo
========================================

This demonstrates converting Elixir code
into natural language explanations.
""")

# Example 1: Function Calls
IO.puts("\n--- Example 1: Function Calls ---\n")

function_calls = [
  "Enum.sort(numbers)",
  "Enum.filter(users, fn u -> u.age > 18 end)",
  "Enum.map(list, fn x -> x * 2 end)",
  "Enum.sum(values)",
  "Enum.count(items)"
]

for code <- function_calls do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  Code: #{code}")
      IO.puts("  Explanation: #{explanation}\n")

    {:error, reason} ->
      IO.puts("  Code: #{code}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 2: Assignments
IO.puts("\n--- Example 2: Assignments ---\n")

assignments = [
  "x = 5",
  "result = a + b",
  "count = length(list)"
]

for code <- assignments do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  Code: #{code}")
      IO.puts("  Explanation: #{explanation}\n")

    {:error, reason} ->
      IO.puts("  Code: #{code}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 3: Arithmetic Operations
IO.puts("\n--- Example 3: Arithmetic Operations ---\n")

arithmetic = [
  "a + b",
  "x * 2",
  "total / count",
  "result - overhead"
]

for code <- arithmetic do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  Code: #{code}")
      IO.puts("  Explanation: #{explanation}\n")

    {:error, reason} ->
      IO.puts("  Code: #{code}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 4: Conditionals
IO.puts("\n--- Example 4: Conditionals ---\n")

conditionals = [
  "if x > 5, do: :ok",
  "if count == 0, do: :empty"
]

for code <- conditionals do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  Code: #{code}")
      IO.puts("  Explanation: #{explanation}\n")

    {:error, reason} ->
      IO.puts("  Code: #{code}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 5: Pipelines
IO.puts("\n--- Example 5: Pipelines ---\n")

pipelines = [
  "list |> Enum.sort()",
  "numbers |> Enum.filter(fn x -> x > 0 end) |> Enum.sum()"
]

for code <- pipelines do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  Code: #{code}")
      IO.puts("  Explanation: #{explanation}\n")

    {:error, reason} ->
      IO.puts("  Code: #{code}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 6: Explanation with AST
IO.puts("\n--- Example 6: Explanation as NL AST ---\n")

code_to_explain = "Enum.sort(numbers)"

case English.explain_code_to_document(Code.string_to_quoted!(code_to_explain)) do
  {:ok, document} ->
    IO.puts("  Code: #{code_to_explain}")
    IO.puts("  Generated Document:")
    IO.puts("    Language: #{document.language}")
    IO.puts("    Paragraphs: #{length(document.paragraphs)}")
    IO.puts("    Metadata: #{inspect(document.metadata, limit: 2)}")

    # Render the document back to text
    case Nasty.render(document) do
      {:ok, text} ->
        IO.puts("    Rendered Text: #{text}")

      {:error, _} ->
        IO.puts("    (Could not render)")
    end

  {:error, reason} ->
    IO.puts("  ✗ Error: #{inspect(reason)}")
end

# Example 7: Practical Use Case - Documenting Code
IO.puts("\n--- Example 7: Practical Use Case - Code Documentation ---\n")
IO.puts("Generating documentation for a data pipeline:\n")

pipeline_steps = [
  {"Load", "File.read(path)"},
  {"Parse", "Jason.decode(json)"},
  {"Filter", "Enum.filter(data, fn x -> x.active end)"},
  {"Transform", "Enum.map(records, fn r -> r.name end)"},
  {"Save", "File.write(output, content)"}
]

IO.puts("Pipeline Documentation:\n")

for {label, code} <- pipeline_steps do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  Step: #{label}")
      IO.puts("  Code: #{code}")
      IO.puts("  Does: #{explanation}\n")

    {:error, _} ->
      IO.puts("  Step: #{label} (explanation unavailable)\n")
  end
end

# Example 8: Reverse Engineering
IO.puts("\n--- Example 8: Understanding Complex Expressions ---\n")

complex_code = [
  "Enum.reduce(list, 0, fn x, acc -> acc + x end)",
  "Enum.filter(users, fn u -> u.role == :admin end)",
  "Enum.map(data, fn item -> item * 2 end)"
]

for code <- complex_code do
  case English.explain_code(code) do
    {:ok, explanation} ->
      IO.puts("  #{code}")
      IO.puts("  → #{explanation}\n")

    {:error, reason} ->
      IO.puts("  #{code}")
      IO.puts("  ✗ #{inspect(reason)}\n")
  end
end

IO.puts("\n========================================")
IO.puts("Code Explanation Demo Complete!")
IO.puts("========================================\n")
