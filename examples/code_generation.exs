# Code Generation Examples
# Demonstrates Natural Language → Code conversion
# Run with: mix run examples/code_generation.exs

alias Nasty.Language.English

IO.puts("""
========================================
Natural Language → Code Generation Demo
========================================

This demonstrates converting natural language commands
into executable Elixir code.
""")

# Example 1: List Operations
IO.puts("\n--- Example 1: List Operations ---\n")

commands = [
  "Sort the numbers",
  "Filter the users",
  "Map the list",
  "Sum the values",
  "Count the items"
]

for command <- commands do
  case English.to_code(command) do
    {:ok, code} ->
      IO.puts("  #{command}")
      IO.puts("  → #{code}\n")

    {:error, reason} ->
      IO.puts("  #{command}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 2: Variable Assignments
IO.puts("\n--- Example 2: Variable Assignments ---\n")

assignments = [
  "X is 5",
  "Set result to 42",
  "Define count as 10"
]

for assignment <- assignments do
  case English.to_code(assignment) do
    {:ok, code} ->
      IO.puts("  #{assignment}")
      IO.puts("  → #{code}\n")

    {:error, reason} ->
      IO.puts("  #{assignment}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 3: Pipelines (Complex Commands)
IO.puts("\n--- Example 3: Complex Operations ---\n")

# Note: These are single commands, not pipelines yet
# Full pipeline support would require more sophisticated parsing

complex_commands = [
  "Sort the numbers",
  "Filter the users",
  "Sum the values"
]

for command <- complex_commands do
  case English.to_code(command) do
    {:ok, code} ->
      IO.puts("  #{command}")
      IO.puts("  → #{code}\n")

    {:error, reason} ->
      IO.puts("  #{command}")
      IO.puts("  ✗ Error: #{inspect(reason)}\n")
  end
end

# Example 4: Intent Recognition (Lower Level)
IO.puts("\n--- Example 4: Intent Recognition (Advanced) ---\n")
IO.puts("Showing the intermediate intent structure:\n")

case English.recognize_intent("Sort the numbers") do
  {:ok, intent} ->
    IO.puts("  Command: \"Sort the numbers\"")
    IO.puts("  Intent Type: #{inspect(intent.type)}")
    IO.puts("  Action: #{inspect(intent.action)}")
    IO.puts("  Target: #{inspect(intent.target)}")
    IO.puts("  Confidence: #{Float.round(intent.confidence, 2)}")

  {:error, reason} ->
    IO.puts("  ✗ Error: #{inspect(reason)}")
end

# Example 5: Code Generation with AST
IO.puts("\n--- Example 5: Generate Elixir AST ---\n")

case English.to_code_ast("Sum the numbers") do
  {:ok, ast} ->
    IO.puts("  Command: \"Sum the numbers\"")
    IO.puts("  Generated AST:")
    IO.puts("  #{inspect(ast, pretty: true)}")
    IO.puts("\n  As code: #{Macro.to_string(ast)}")

  {:error, reason} ->
    IO.puts("  ✗ Error: #{inspect(reason)}")
end

# Example 6: Practical Use Case - Building Pipelines
IO.puts("\n--- Example 6: Practical Use Case ---\n")
IO.puts("Building a data processing pipeline:\n")

# In a real application, you might combine multiple commands
steps = [
  {"Load data", "Get the data"},
  {"Filter", "Filter the records"},
  {"Transform", "Map the items"},
  {"Aggregate", "Sum the totals"}
]

IO.puts("Pipeline steps:")

for {label, command} <- steps do
  case English.to_code(command) do
    {:ok, code} ->
      IO.puts("  #{label}: #{code}")

    {:error, _} ->
      IO.puts("  #{label}: [error]")
  end
end

IO.puts("\n========================================")
IO.puts("Code Generation Demo Complete!")
IO.puts("========================================\n")
