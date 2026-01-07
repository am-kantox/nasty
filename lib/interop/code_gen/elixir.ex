defmodule Nasty.Interop.CodeGen.Elixir do
  @moduledoc """
  Generates Elixir code from natural language intents.

  This module converts `Nasty.AST.Intent` structures into executable Elixir code
  by generating Elixir AST using the `quote` macro and pattern matching on intent types.

  ## Supported Patterns

  ### List Operations
  - "Sort X" → `Enum.sort(x)`
  - "Filter X" → `Enum.filter(x, fn item -> condition end)`
  - "Map X" → `Enum.map(x, fn item -> transformation end)`
  - "Sum X" → `Enum.sum(x)`
  - "Count X" → `Enum.count(x)`

  ### Arithmetic
  - "Add X and Y" → `x + y`
  - "X plus Y" → `x + y`
  - "Multiply X by Y" → `x * y`

  ### Assignments
  - "X is Y" → `x = y`
  - "Set X to Y" → `x = y`

  ### Conditionals
  - "If X then Y" → `if x, do: y`

  ## Examples

      # Action intent → Function call
      intent = %Intent{type: :action, action: "sort", target: "list"}
      {:ok, ast} = Elixir.generate(intent)
      Macro.to_string(ast)  # => "Enum.sort(list)"

      # Definition intent → Assignment
      intent = %Intent{type: :definition, action: "assign", target: "x", arguments: [5]}
      {:ok, ast} = Elixir.generate(intent)
      Macro.to_string(ast)  # => "x = 5"
  """

  alias Nasty.AST.Intent

  @doc """
  Generates Elixir AST from an intent.

  ## Parameters

  - `intent` - The intent to convert
  - `opts` - Options (currently unused)

  ## Returns

  - `{:ok, Macro.t()}` - Elixir AST
  - `{:error, reason}` - Generation error

  ## Examples

      iex> intent = %Intent{type: :action, action: "sort", target: "numbers", ...}
      iex> {:ok, ast} = Elixir.generate(intent)
      iex> Macro.to_string(ast)
      "Enum.sort(numbers)"
  """
  @spec generate(Intent.t(), keyword()) :: {:ok, Macro.t()} | {:error, term()}
  def generate(%Intent{type: type} = intent, opts \\ []) do
    case type do
      :action -> generate_action(intent, opts)
      :query -> generate_query(intent, opts)
      :definition -> generate_definition(intent, opts)
      :conditional -> generate_conditional(intent, opts)
    end
  end

  @doc """
  Generates Elixir code string from an intent.

  This is a convenience function that generates AST and converts it to a string.

  ## Examples

      iex> intent = %Intent{type: :action, action: "sort", target: "list", ...}
      iex> {:ok, code} = Elixir.generate_string(intent)
      iex> code
      "Enum.sort(list)"
  """
  @spec generate_string(Intent.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_string(%Intent{} = intent, opts \\ []) do
    case generate(intent, opts) do
      {:ok, ast} ->
        {:ok, Macro.to_string(ast)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that generated code is syntactically correct.

  ## Examples

      iex> ast = quote do: Enum.sort(list)
      iex> Elixir.validate(ast)
      {:ok, ast}
  """
  @spec validate(Macro.t()) :: {:ok, Macro.t()} | {:error, term()}
  def validate(ast) do
    code = Macro.to_string(ast)

    case Code.string_to_quoted(code) do
      {:ok, _validated_ast} ->
        {:ok, ast}

      {:error, reason} ->
        {:error, {:invalid_syntax, reason}}
    end
  end

  # Private generation functions

  # Generate action intents → Function calls
  defp generate_action(%Intent{action: action, target: target} = intent, _opts) do
    var_ast = to_variable_ast(target)

    ast =
      case action do
        # List operations (Enum module)
        "sort" ->
          generate_enum_call(:sort, [var_ast])

        "filter" ->
          # Generate filter with constraint if available
          predicate = build_filter_predicate(intent.constraints)
          generate_enum_call(:filter, [var_ast, predicate])

        "map" ->
          # Generate map with transformation
          transformation = build_map_transformation(intent.arguments, intent.constraints)
          generate_enum_call(:map, [var_ast, transformation])

        "reduce" ->
          # Generate reduce with accumulator and function
          {initial, reducer} = build_reduce_args(intent.arguments)
          generate_enum_call(:reduce, [var_ast, initial, reducer])

        "sum" ->
          generate_enum_call(:sum, [var_ast])

        "count" ->
          generate_enum_call(:count, [var_ast])

        "find" ->
          predicate = build_filter_predicate(intent.constraints)
          generate_enum_call(:find, [var_ast, predicate])

        "reject" ->
          predicate = build_filter_predicate(intent.constraints)
          generate_enum_call(:reject, [var_ast, predicate])

        # Arithmetic operations
        "add" ->
          generate_arithmetic(:+, [var_ast | Enum.map(intent.arguments, &to_literal_ast/1)])

        "subtract" ->
          generate_arithmetic(:-, [var_ast | Enum.map(intent.arguments, &to_literal_ast/1)])

        "multiply" ->
          generate_arithmetic(:*, [var_ast | Enum.map(intent.arguments, &to_literal_ast/1)])

        "divide" ->
          generate_arithmetic(:/, [var_ast | Enum.map(intent.arguments, &to_literal_ast/1)])

        # Unknown action
        _ ->
          # Try to generate generic function call
          generate_generic_call(action, [var_ast | Enum.map(intent.arguments, &to_literal_ast/1)])
      end

    validate(ast)
  end

  # Generate query intents → Assertions/comparisons
  defp generate_query(%Intent{action: action, target: target, arguments: args}, _opts) do
    left = to_variable_ast(target)
    right = if Enum.empty?(args), do: nil, else: to_literal_ast(hd(args))

    ast =
      case action do
        "equal" when not is_nil(right) ->
          quote do: unquote(left) == unquote(right)

        "match" when not is_nil(right) ->
          quote do: unquote(left) == unquote(right)

        "check" ->
          # Just the variable itself as a boolean check
          left

        _ ->
          # Unknown query - generate comparison
          if right do
            quote do: unquote(left) == unquote(right)
          else
            left
          end
      end

    validate(ast)
  end

  # Generate definition intents → Variable assignments
  defp generate_definition(%Intent{target: target, arguments: args}, _opts) do
    var_ast = to_variable_ast(target)

    value_ast =
      case args do
        [] ->
          # No arguments - assign nil or error
          nil

        [single] ->
          # Single argument - direct assignment
          to_literal_ast(single)

        [op | operands] when is_binary(op) and op in ["+", "-", "*", "/"] ->
          # Arithmetic expression
          operator = String.to_atom(op)
          operand_asts = Enum.map(operands, &to_literal_ast/1)
          generate_arithmetic(operator, operand_asts)

        multiple ->
          # Multiple arguments - create a list
          Enum.map(multiple, &to_literal_ast/1)
      end

    ast = quote do: unquote(var_ast) = unquote(value_ast)
    validate(ast)
  end

  # Generate conditional intents → if/case expressions
  defp generate_conditional(
         %Intent{target: target, arguments: args, constraints: constraints},
         _opts
       ) do
    condition = build_condition(target, constraints)

    consequence =
      case args do
        [] -> quote do: :ok
        [single] -> to_literal_ast(single)
        multiple -> Enum.map(multiple, &to_literal_ast/1)
      end

    ast = quote do: if(unquote(condition), do: unquote(consequence))
    validate(ast)
  end

  # Helper: Generate Enum.function_name(args)
  defp generate_enum_call(function_name, args) do
    quote do: Enum.unquote(function_name)(unquote_splicing(args))
  end

  # Helper: Generate generic module.function(args) call
  defp generate_generic_call(function_name, args) do
    atom_name = String.to_atom(function_name)
    quote do: unquote(atom_name)(unquote_splicing(args))
  end

  # Helper: Generate arithmetic expression
  defp generate_arithmetic(_operator, []) do
    0
  end

  defp generate_arithmetic(_operator, [single]) do
    single
  end

  defp generate_arithmetic(operator, [first, second | rest]) do
    # Build left-associative tree: ((a + b) + c) + d
    initial_expr = {operator, [], [first, second]}

    Enum.reduce(rest, initial_expr, fn operand, acc ->
      {operator, [], [acc, operand]}
    end)
  end

  # Helper: Build filter predicate from constraints
  defp build_filter_predicate([]), do: quote(do: fn item -> true end)

  defp build_filter_predicate(constraints) do
    # Build condition from all constraints combined with AND logic
    conditions =
      Enum.map(constraints, fn constraint ->
        case constraint do
          {:comparison, :greater_than, value} ->
            quote do: item > unquote(value)

          {:comparison, :less_than, value} ->
            quote do: item < unquote(value)

          {:comparison, :greater_equal, value} ->
            quote do: item >= unquote(value)

          {:comparison, :less_equal, value} ->
            quote do: item <= unquote(value)

          {:equality, value} ->
            quote do: item == unquote(value)

          {:inequality, value} ->
            quote do: item != unquote(value)

          _ ->
            quote do: true
        end
      end)

    # Combine all conditions with AND
    combined_condition = combine_conditions_with_and(conditions)

    quote do: fn item -> unquote(combined_condition) end
  end

  # Helper: Combine multiple conditions with AND logic
  defp combine_conditions_with_and([]), do: quote(do: true)
  defp combine_conditions_with_and([single]), do: single

  defp combine_conditions_with_and([first | rest]) do
    Enum.reduce(rest, first, fn condition, acc ->
      quote do: unquote(acc) and unquote(condition)
    end)
  end

  # Helper: Build map transformation
  defp build_map_transformation([], _constraints) do
    # Default: identity transformation
    quote do: fn item -> item end
  end

  defp build_map_transformation([transformation | _], _constraints) do
    # Use first argument as transformation hint
    case transformation do
      # Arithmetic operations
      value when is_number(value) ->
        quote do: fn item -> item * unquote(value) end

      # String operations
      "uppercase" ->
        quote do: fn item -> String.upcase(item) end

      "lowercase" ->
        quote do: fn item -> String.downcase(item) end

      # Default: identity
      _ ->
        quote do: fn item -> item end
    end
  end

  # Helper: Build reduce arguments
  defp build_reduce_args([]) do
    # Default: sum reduction
    {0, quote(do: fn item, acc -> acc + item end)}
  end

  defp build_reduce_args([initial | _]) when is_number(initial) do
    # Numeric initial value - assume sum
    {initial, quote(do: fn item, acc -> acc + item end)}
  end

  defp build_reduce_args(_) do
    # Unknown - default to list accumulation
    {[], quote(do: fn item, acc -> [item | acc] end)}
  end

  # Helper: Build condition from target and constraints
  defp build_condition(target, []) do
    # No constraints - just check target truthiness
    to_variable_ast(target)
  end

  defp build_condition(target, constraints) do
    var_ast = to_variable_ast(target)

    # Build condition from first constraint
    case hd(constraints) do
      {:comparison, :greater_than, value} ->
        quote do: unquote(var_ast) > unquote(value)

      {:comparison, :less_than, value} ->
        quote do: unquote(var_ast) < unquote(value)

      {:equality, value} ->
        value_ast = to_literal_ast(value)
        quote do: unquote(var_ast) == unquote(value_ast)

      _ ->
        var_ast
    end
  end

  # Helper: Convert string to variable AST
  defp to_variable_ast(nil), do: quote(do: _)

  defp to_variable_ast(name) when is_binary(name) do
    # Convert string to atom, then to variable AST
    atom_name = String.to_atom(name)
    {atom_name, [], Elixir}
  end

  # Helper: Convert value to literal AST
  defp to_literal_ast(value) when is_integer(value), do: value
  defp to_literal_ast(value) when is_float(value), do: value
  defp to_literal_ast(value) when is_boolean(value), do: value
  defp to_literal_ast(value) when is_atom(value), do: value

  defp to_literal_ast(value) when is_binary(value) do
    # Check if it looks like a variable name (lowercase, no spaces)
    if value =~ ~r/^[a-z_][a-z0-9_]*$/ do
      # Treat as variable
      to_variable_ast(value)
    else
      # Treat as string literal
      value
    end
  end

  defp to_literal_ast(value) when is_list(value) do
    Enum.map(value, &to_literal_ast/1)
  end

  defp to_literal_ast(_value), do: nil
end
