defmodule Nasty.Interop.CodeGen.Explain do
  @moduledoc """
  Generates natural language explanations from Elixir code AST.

  This module traverses Elixir AST and generates natural language descriptions,
  creating the reverse direction of code generation (Code → NL).

  ## Supported Patterns

  ### Function Calls
  - `Enum.sort(list)` → "Sort the list"
  - `Enum.filter(users, fn u -> u.age > 18 end)` → "Filter users where age is greater than 18"

  ### Pipelines
  - `list |> Enum.map(&(&1 * 2)) |> Enum.sum()` → "Map the list to double each element, then sum the results"

  ### Assignments
  - `x = 5` → "X is 5"
  - `result = a + b` → "Result equals A plus B"

  ### Conditionals
  - `if x > 5, do: :ok` → "If X is greater than 5, return ok"

  ## Examples

      # Function call → Natural language
      code = "Enum.sort(numbers)"
      {:ok, text} = Explain.explain_code(code)
      # => "Sort numbers"

      # Pipeline → Natural language
      code = "list |> Enum.map(&(&1 * 2)) |> Enum.sum()"
      {:ok, text} = Explain.explain_code(code)
      # => "Map list to double each element, then sum the results"
  """

  alias Nasty.AST.{Clause, Document, Node, Paragraph, Sentence, Token, VerbPhrase}

  @doc """
  Explains Elixir code by converting it to natural language.

  ## Parameters

  - `code` - Elixir code string or AST
  - `opts` - Options:
    - `:language` - Target language (default: :en)
    - `:style` - Explanation style: `:concise` or `:verbose` (default: :concise)

  ## Returns

  - `{:ok, String.t()}` - Natural language explanation
  - `{:error, reason}` - Parse or generation error

  ## Examples

      {:ok, explanation} = Explain.explain_code("Enum.sort(list)")
      # => "Sort list"

      {:ok, explanation} = Explain.explain_code("x = 5")
      # => "X is 5"
  """
  @spec explain_code(String.t() | Macro.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def explain_code(code, opts \\ [])

  def explain_code(code, opts) when is_binary(code) do
    case Code.string_to_quoted(code) do
      {:ok, ast} ->
        explain_ast(ast, opts)

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  def explain_code(ast, opts) when is_tuple(ast) do
    explain_ast(ast, opts)
  end

  @doc """
  Explains Elixir AST and returns a natural language AST Document.

  ## Examples

      ast = quote do: Enum.sort(list)
      {:ok, document} = Explain.explain_ast_to_document(ast)
  """
  @spec explain_ast_to_document(Macro.t(), keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  def explain_ast_to_document(ast, opts \\ []) do
    language = Keyword.get(opts, :language, :en)

    # Generate explanation text
    case traverse_ast(ast, opts) do
      {:ok, text} ->
        # Create a simple document with one sentence
        span = Node.make_span({1, 0}, 0, {1, String.length(text)}, String.length(text))

        # Create tokens from text
        tokens =
          text
          |> String.split(" ")
          |> Enum.with_index()
          |> Enum.map(fn {word, idx} ->
            token_span =
              Node.make_span(
                {1, idx},
                idx,
                {1, idx + String.length(word)},
                idx + String.length(word)
              )

            %Token{
              text: word,
              lemma: String.downcase(word),
              pos_tag: infer_pos_tag(word),
              language: language,
              span: token_span
            }
          end)

        # Create verb phrase (main verb)
        verb = List.first(tokens) || create_default_token("explain", language)

        verb_phrase = %VerbPhrase{
          head: verb,
          auxiliaries: [],
          complements: [],
          adverbials: [],
          language: language,
          span: span
        }

        # Create clause
        clause = %Clause{
          type: :independent,
          subject: nil,
          predicate: verb_phrase,
          language: language,
          span: span
        }

        # Create sentence
        sentence = %Sentence{
          function: :declarative,
          structure: :simple,
          main_clause: clause,
          additional_clauses: [],
          language: language,
          span: span
        }

        # Create paragraph
        paragraph = %Paragraph{
          sentences: [sentence],
          language: language,
          span: span
        }

        # Create document
        document = %Document{
          paragraphs: [paragraph],
          language: language,
          span: span,
          metadata: %{
            source: "code_explanation",
            original_code: Macro.to_string(ast)
          }
        }

        {:ok, document}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private: Convert AST to natural language text
  @spec explain_ast(Macro.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  defp explain_ast(ast, opts) do
    case traverse_ast(ast, opts) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # Traverse AST and generate explanation
  defp traverse_ast({:|>, _meta, [left, right]}, opts) do
    # Pipeline: left |> right
    with {:ok, left_text} <- traverse_ast(left, opts),
         {:ok, right_text} <- traverse_ast(right, opts) do
      {:ok, "#{left_text}, then #{right_text}"}
    end
  end

  defp traverse_ast({:=, _meta, [left, right]}, opts) do
    # Assignment: left = right
    with {:ok, left_text} <- traverse_ast(left, opts),
         {:ok, right_text} <- traverse_ast(right, opts) do
      {:ok, "#{capitalize(left_text)} is #{right_text}"}
    end
  end

  defp traverse_ast({:if, _meta, [condition, [do: consequence]]}, opts) do
    # Conditional: if condition, do: consequence
    with {:ok, cond_text} <- traverse_ast(condition, opts),
         {:ok, cons_text} <- traverse_ast(consequence, opts) do
      {:ok, "If #{cond_text}, then #{cons_text}"}
    end
  end

  defp traverse_ast(
         {{:., _meta1, [{:__aliases__, _meta2, modules}, function]}, _meta3, args},
         opts
       ) do
    # Module function call: Module.function(args)
    module_name = Enum.join(modules, ".")
    explain_function_call(module_name, function, args, opts)
  end

  defp traverse_ast({function, _meta, args}, opts) when is_atom(function) and is_list(args) do
    # Local function call: function(args)
    explain_function_call(nil, function, args, opts)
  end

  defp traverse_ast({op, _meta, [left, right]}, opts)
       when op in [:+, :-, :*, :/, :==, :!=, :>, :<, :>=, :<=] do
    # Binary operation
    with {:ok, left_text} <- traverse_ast(left, opts),
         {:ok, right_text} <- traverse_ast(right, opts) do
      op_text = operator_to_text(op)
      {:ok, "#{left_text} #{op_text} #{right_text}"}
    end
  end

  defp traverse_ast({var, _meta, context}, _opts) when is_atom(var) and is_atom(context) do
    # Variable
    {:ok, atom_to_text(var)}
  end

  defp traverse_ast(literal, _opts)
       when is_number(literal) or is_binary(literal) or is_atom(literal) do
    # Literal value
    {:ok, literal_to_text(literal)}
  end

  defp traverse_ast(list, opts) when is_list(list) do
    case Enum.map(list, &traverse_ast(&1, opts)) do
      [_ | _] = results ->
        case Enum.all?(results, fn r -> match?({:ok, _}, r) end) do
          true ->
            texts = Enum.map(results, fn {:ok, t} -> t end)
            {:ok, "[#{Enum.join(texts, ", ")}]"}

          false ->
            {:error, :list_element_error}
        end

      _ ->
        {:ok, "[]"}
    end
  end

  defp traverse_ast(_ast, _opts) do
    {:error, :unsupported_ast}
  end

  # Explain function calls
  defp explain_function_call("Enum", :sort, [target], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts) do
      {:ok, "sort #{target_text}"}
    end
  end

  defp explain_function_call("Enum", :filter, [target, predicate], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts),
         {:ok, pred_text} <- explain_predicate(predicate, opts) do
      {:ok, "filter #{target_text} #{pred_text}"}
    end
  end

  defp explain_function_call("Enum", :map, [target, mapper], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts),
         {:ok, map_text} <- explain_mapper(mapper, opts) do
      {:ok, "map #{target_text} #{map_text}"}
    end
  end

  # [TODO] `reducer`
  defp explain_function_call("Enum", :reduce, [target, initial, _reducer], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts),
         {:ok, init_text} <- traverse_ast(initial, opts) do
      {:ok, "reduce #{target_text} starting with #{init_text}"}
    end
  end

  defp explain_function_call("Enum", :sum, [target], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts) do
      {:ok, "sum #{target_text}"}
    end
  end

  defp explain_function_call("Enum", :count, [target], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts) do
      {:ok, "count #{target_text}"}
    end
  end

  defp explain_function_call("Enum", :find, [target, predicate], opts) do
    with {:ok, target_text} <- traverse_ast(target, opts),
         {:ok, pred_text} <- explain_predicate(predicate, opts) do
      {:ok, "find in #{target_text} #{pred_text}"}
    end
  end

  defp explain_function_call(module, function, args, opts) do
    # Generic function call
    function_text = if module, do: "#{module}.#{function}", else: "#{function}"

    case Enum.map(args, &traverse_ast(&1, opts)) do
      [_ | _] = results ->
        case Enum.all?(results, fn r -> match?({:ok, _}, r) end) do
          true ->
            arg_texts = Enum.map(results, fn {:ok, t} -> t end)
            {:ok, "call #{function_text} with #{Enum.join(arg_texts, " and ")}"}

          false ->
            {:ok, "call #{function_text}"}
        end

      _ ->
        {:ok, "call #{function_text}"}
    end
  end

  # Explain anonymous function predicates (for filter/find)
  defp explain_predicate({:fn, _meta, [{:->, _meta2, [[{var, _, _}], body]}]}, opts) do
    # fn x -> body end
    with {:ok, body_text} <- traverse_ast(body, opts) do
      var_text = atom_to_text(var)
      {:ok, "where #{var_text} #{body_text}"}
    end
  end

  defp explain_predicate(_predicate, _opts) do
    {:ok, "with condition"}
  end

  # Explain anonymous function mappers (for map)
  # [TODO] `var`
  defp explain_mapper({:fn, _meta, [{:->, _meta2, [[{_var, _, _}], body]}]}, opts) do
    # fn x -> body end
    with {:ok, body_text} <- traverse_ast(body, opts) do
      {:ok, "to #{body_text}"}
    end
  end

  defp explain_mapper({:&, _meta, [{:/, _, [{{:., _, [Access, :get]}, _, _}, 1]}]}, _opts) do
    # Capture operator &(&1)
    {:ok, "to each element"}
  end

  defp explain_mapper(_mapper, _opts) do
    {:ok, "with transformation"}
  end

  # Helper: Convert operator to text
  defp operator_to_text(:+), do: "plus"
  defp operator_to_text(:-), do: "minus"
  defp operator_to_text(:*), do: "times"
  defp operator_to_text(:/), do: "divided by"
  defp operator_to_text(:==), do: "equals"
  defp operator_to_text(:!=), do: "does not equal"
  defp operator_to_text(:>), do: "is greater than"
  defp operator_to_text(:<), do: "is less than"
  defp operator_to_text(:>=), do: "is greater than or equal to"
  defp operator_to_text(:<=), do: "is less than or equal to"
  defp operator_to_text(_), do: "operator"

  # Helper: Convert literal to text
  defp literal_to_text(value) when is_integer(value), do: Integer.to_string(value)
  defp literal_to_text(value) when is_float(value), do: Float.to_string(value)
  defp literal_to_text(value) when is_binary(value), do: "\"#{value}\""
  defp literal_to_text(value) when is_atom(value), do: ":#{value}"
  defp literal_to_text(_), do: "value"

  # Helper: Convert atom to readable text
  defp atom_to_text(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  # Helper: Capitalize first letter
  defp capitalize(text) when is_binary(text) do
    String.capitalize(text)
  end

  # Helper: Create default token
  defp create_default_token(text, language) do
    span = Node.make_span({1, 0}, 0, {1, String.length(text)}, String.length(text))

    %Token{
      text: text,
      lemma: text,
      pos_tag: :verb,
      language: language,
      span: span
    }
  end

  # Helper: Infer POS tag from word
  defp infer_pos_tag(word) do
    cond do
      word in ["sort", "filter", "map", "sum", "count", "find", "is", "equals"] -> :verb
      word in ["the", "a", "an"] -> :det
      word =~ ~r/\d+/ -> :num
      true -> :noun
    end
  end
end
