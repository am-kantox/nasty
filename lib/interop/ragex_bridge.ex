defmodule Nasty.Interop.RagexBridge do
  @moduledoc """
  Optional integration with Ragex knowledge graph for context-aware code generation.

  This module provides utilities to query the Ragex knowledge graph for:
  - Available functions in the codebase
  - Function signatures and documentation
  - Semantic similarity search for function suggestions

  The bridge gracefully degrades if Ragex is not available or not running.

  ## Usage

      # Check if Ragex is available
      if RagexBridge.available?() do
        # Query for function suggestions
        {:ok, functions} = RagexBridge.suggest_functions("sort a list")
      end

  ## Configuration

  The bridge can be configured via application environment:

      config :nasty, :ragex,
        enabled: true,
        path: "/path/to/ragex"
  """

  @doc """
  Checks if Ragex integration is available and enabled.

  ## Examples

      iex> RagexBridge.available?()
      false  # Unless Ragex is configured and running
  """
  @spec available?() :: boolean()
  def available? do
    case Application.get_env(:nasty, :ragex) do
      nil ->
        false

      config ->
        Keyword.get(config, :enabled, false) and ragex_module_loaded?()
    end
  end

  @doc """
  Suggests functions from the codebase based on natural language query.

  Uses semantic search via Ragex's vector embeddings to find relevant functions.

  ## Parameters

  - `query` - Natural language description of desired functionality
  - `opts` - Options:
    - `:limit` - Maximum number of suggestions (default: 5)
    - `:threshold` - Minimum similarity score 0.0-1.0 (default: 0.7)
    - `:module` - Filter by module name (optional)

  ## Returns

  - `{:ok, [%{name: String.t(), module: String.t(), doc: String.t(), score: float()}]}`
  - `{:error, :ragex_unavailable}` - If Ragex is not available
  - `{:error, reason}` - Other errors

  ## Examples

      {:ok, suggestions} = RagexBridge.suggest_functions("sort a list")
      # => [{%{name: "sort", module: "Enum", doc: "Sorts...", score: 0.95}, ...}]
  """
  @spec suggest_functions(String.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def suggest_functions(query, opts \\ []) do
    if available?() do
      # Use Ragex semantic search
      do_suggest_functions(query, opts)
    else
      {:error, :ragex_unavailable}
    end
  end

  @doc """
  Gets function signature and documentation from the knowledge graph.

  ## Parameters

  - `module` - Module name (e.g., "Enum")
  - `function` - Function name (e.g., "sort")
  - `arity` - Function arity (optional)

  ## Returns

  - `{:ok, %{signature: String.t(), doc: String.t(), examples: [String.t()]}}`
  - `{:error, :not_found}` - Function not in knowledge graph
  - `{:error, :ragex_unavailable}` - If Ragex is not available

  ## Examples

      {:ok, info} = RagexBridge.get_function_info("Enum", "sort", 1)
      # => %{signature: "sort(enumerable)", doc: "Sorts...", ...}
  """
  @spec get_function_info(String.t(), String.t(), non_neg_integer() | nil) ::
          {:ok, map()} | {:error, term()}
  def get_function_info(module, function, arity \\ nil) do
    if available?() do
      do_get_function_info(module, function, arity)
    else
      {:error, :ragex_unavailable}
    end
  end

  @doc """
  Queries the knowledge graph for modules matching a pattern.

  ## Examples

      {:ok, modules} = RagexBridge.find_modules("Enum")
      # => ["Enum", "Enumerable"]
  """
  @spec find_modules(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def find_modules(pattern) do
    if available?() do
      do_find_modules(pattern)
    else
      {:error, :ragex_unavailable}
    end
  end

  # Private implementation functions

  defp ragex_module_loaded? do
    Code.ensure_loaded?(Ragex)
  end

  defp do_suggest_functions(query, opts) do
    limit = Keyword.get(opts, :limit, 5)
    threshold = Keyword.get(opts, :threshold, 0.7)
    module_filter = Keyword.get(opts, :module)

    # Build search options
    search_opts = [
      limit: limit,
      threshold: threshold,
      node_type: "function"
    ]

    search_opts =
      if module_filter do
        Keyword.put(search_opts, :graph_filter, %{module: module_filter})
      else
        search_opts
      end

    # Perform semantic search
    case call_ragex(:semantic_search, [query, search_opts]) do
      {:ok, results} ->
        # Transform results to our format
        suggestions =
          Enum.map(results, fn result ->
            %{
              name: Map.get(result, :name, ""),
              module: Map.get(result, :module, ""),
              doc: Map.get(result, :description, ""),
              score: Map.get(result, :similarity, 0.0)
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_get_function_info(module, function, arity) do
    # Query Ragex graph for function node
    query_params = %{
      module: module,
      function: function
    }

    query_params =
      if arity do
        Map.put(query_params, :arity, arity)
      else
        query_params
      end

    case call_ragex(:query_graph, [
           %{query_type: "find_function", params: query_params}
         ]) do
      {:ok, [result | _]} ->
        # Extract function info
        info = %{
          signature: build_signature(result),
          doc: Map.get(result, :doc, ""),
          examples: Map.get(result, :examples, [])
        }

        {:ok, info}

      {:ok, []} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_find_modules(pattern) do
    case call_ragex(:query_graph, [
           %{
             query_type: "find_module",
             params: %{name: pattern}
           }
         ]) do
      {:ok, results} ->
        modules = Enum.map(results, fn result -> Map.get(result, :name, "") end)
        {:ok, modules}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper: Call Ragex function dynamically
  defp call_ragex(function_name, args) do
    # Attempt to call Ragex module
    # In a real implementation, this would use the Ragex API
    # For now, we return mock data for testing
    apply(Ragex, function_name, args)
  rescue
    UndefinedFunctionError ->
      {:error, :function_not_found}

    _ ->
      {:error, :ragex_error}
  end

  # Helper: Build function signature string
  defp build_signature(function_info) do
    name = Map.get(function_info, :name, "")
    arity = Map.get(function_info, :arity, 0)

    args =
      if arity > 0 do
        Enum.map_join(1..arity, ", ", fn i -> "arg#{i}" end)
      else
        ""
      end

    "#{name}(#{args})"
  end

  @doc """
  Enhances an intent with context from the knowledge graph.

  Adds suggestions for available functions that match the intent's action.

  ## Examples

      intent = %Intent{type: :action, action: "sort", target: "list"}
      {:ok, enhanced} = RagexBridge.enhance_intent(intent)
      # intent.metadata will include :ragex_suggestions
  """
  @spec enhance_intent(Nasty.AST.Intent.t()) ::
          {:ok, Nasty.AST.Intent.t()} | {:error, term()}
  def enhance_intent(%Nasty.AST.Intent{action: action} = intent) do
    case suggest_functions(action, limit: 3) do
      {:ok, suggestions} ->
        # Add suggestions to intent metadata
        enhanced =
          Map.update!(intent, :metadata, fn meta ->
            Map.put(meta, :ragex_suggestions, suggestions)
          end)

        {:ok, enhanced}

      {:error, :ragex_unavailable} ->
        # Return unchanged intent if Ragex unavailable
        {:ok, intent}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
