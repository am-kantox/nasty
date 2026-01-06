defmodule Nasty.Rendering.Visualization do
  @moduledoc """
  Generates visual representations of AST structures.

  Exports AST to DOT format for rendering with Graphviz tools.
  Supports parse trees, dependency graphs, and entity graphs.

  ## Examples

      # Generate parse tree
      iex> dot = Nasty.Rendering.Visualization.to_dot(document, type: :parse_tree)
      iex> File.write("tree.dot", dot)
      iex> System.cmd("dot", ["-Tpng", "tree.dot", "-o", "tree.png"])

      # Generate dependency graph
      iex> dot = Nasty.Rendering.Visualization.to_dot(sentence, type: :dependencies)
      iex> File.write("deps.dot", dot)

  ## DOT Format

  The DOT format is used by Graphviz to render graphs.
  See: https://graphviz.org/doc/info/lang.html
  """

  alias Nasty.AST.{
    Clause,
    Document,
    NounPhrase,
    Paragraph,
    Sentence,
    Token,
    VerbPhrase
  }

  @typedoc """
  Visualization options.

  - `:type` - Type of visualization (`:parse_tree`, `:dependencies`, `:entities`)
  - `:format` - Output format (`:dot`, `:json`) (default: `:dot`)
  - `:rankdir` - Graph direction (`TB` top-bottom, `LR` left-right) (default: `TB`)
  - `:show_pos_tags` - Whether to show POS tags (default: true)
  - `:show_spans` - Whether to show position spans (default: false)
  """
  @type options :: [
          type: :parse_tree | :dependencies | :entities,
          format: :dot | :json,
          rankdir: String.t(),
          show_pos_tags: boolean(),
          show_spans: boolean()
        ]

  @doc """
  Converts an AST node to DOT format for Graphviz.

  ## Examples

      iex> Nasty.Rendering.Visualization.to_dot(document)
      "digraph AST {\\n  rankdir=TB;\\n  ..."

      iex> Nasty.Rendering.Visualization.to_dot(sentence, type: :dependencies)
      "digraph Dependencies {\\n  ..."
  """
  @spec to_dot(term(), options()) :: String.t()
  def to_dot(node, opts \\ []) do
    type = Keyword.get(opts, :type, :parse_tree)
    rankdir = Keyword.get(opts, :rankdir, "TB")

    case type do
      :parse_tree -> parse_tree_to_dot(node, rankdir, opts)
      :dependencies -> dependencies_to_dot(node, rankdir, opts)
      :entities -> entities_to_dot(node, rankdir, opts)
    end
  end

  @doc """
  Converts an AST node to JSON format for d3.js or other visualization tools.

  ## Examples

      iex> Nasty.Rendering.Visualization.to_json(document)
      "{\"type\": \"Document\", \"language\": \"en\", \"children\": [...]}"
  """
  @spec to_json(term(), options()) :: String.t()
  def to_json(node, _opts \\ []) do
    node
    |> to_json_structure()
    |> :json.encode()
    |> to_string()
  end

  # Private: Convert parse tree to DOT
  defp parse_tree_to_dot(node, rankdir, opts) do
    {nodes, edges, _counter} = build_parse_tree(node, opts, 1)

    header = """
    digraph ParseTree {
      rankdir=#{rankdir};
      node [shape=box, style=rounded, fontname="Arial"];
      edge [fontname="Arial"];
    """

    body =
      (nodes ++ edges)
      |> Enum.join("\n  ")

    header <> "  " <> body <> "\n}\n"
  end

  # Private: Convert dependencies to DOT
  defp dependencies_to_dot(node, rankdir, opts) do
    show_pos = Keyword.get(opts, :show_pos_tags, true)

    # Extract tokens and dependencies
    tokens = extract_tokens_ordered(node)
    deps = extract_dependencies(node)

    # Generate node definitions
    nodes =
      tokens
      |> Enum.with_index(1)
      |> Enum.map(fn {token, idx} ->
        label = if show_pos, do: "#{token.text}\\n[#{token.pos_tag}]", else: token.text
        ~s(  n#{idx} [label="#{escape_label(label)}"];)
      end)

    # Generate edges for dependencies
    edges =
      Enum.map(deps, fn dep ->
        head_idx = find_token_index(tokens, dep.head) + 1
        dep_idx = find_token_index(tokens, dep.dependent) + 1
        ~s(  n#{head_idx} -> n#{dep_idx} [label="#{dep.relation}"];)
      end)

    header = """
    digraph Dependencies {
      rankdir=#{rankdir};
      node [shape=circle, fontname="Arial"];
      edge [fontname="Arial"];
    """

    body = (nodes ++ edges) |> Enum.join("\n")

    header <> body <> "\n}\n"
  end

  # Private: Convert entity graph to DOT
  defp entities_to_dot(node, rankdir, _opts) do
    alias Nasty.Utils.Query

    entities = Query.extract_entities(node)

    # Generate entity nodes
    nodes =
      entities
      |> Enum.with_index(1)
      |> Enum.map(fn {entity, idx} ->
        color = entity_color(entity.type)

        ~s(  e#{idx} [label="#{escape_label(entity.text)}\\n[#{entity.type}]", fillcolor="#{color}", style=filled];)
      end)

    # [TODO]: Extract relations between entities when relation extraction is implemented
    edges = []

    header = """
    digraph Entities {
      rankdir=#{rankdir};
      node [shape=ellipse, fontname="Arial"];
      edge [fontname="Arial"];
    """

    body = (nodes ++ edges) |> Enum.join("\n")

    header <> body <> "\n}\n"
  end

  # Private: Build parse tree nodes and edges
  defp build_parse_tree(node, opts, counter) do
    show_pos = Keyword.get(opts, :show_pos_tags, true)
    show_spans = Keyword.get(opts, :show_spans, false)

    node_id = "n#{counter}"
    label = node_label(node, show_pos, show_spans)
    color = node_color(node)

    node_def =
      ~s(#{node_id} [label="#{escape_label(label)}", fillcolor="#{color}", style=filled];)

    children = get_children(node)

    {child_nodes, child_edges, final_counter} =
      Enum.reduce(children, {[], [], counter + 1}, fn child, {nodes, edges, cnt} ->
        {child_node_defs, child_edge_defs, new_cnt} = build_parse_tree(child, opts, cnt)
        child_id = "n#{cnt}"
        edge = ~s(#{node_id} -> #{child_id};)
        {nodes ++ child_node_defs, edges ++ child_edge_defs ++ [edge], new_cnt}
      end)

    {[node_def | child_nodes], child_edges, final_counter}
  end

  # Private: Node label for parse tree
  defp node_label(%Document{language: lang}, _show_pos, _show_spans),
    do: "Document\\n(#{lang})"

  defp node_label(%Paragraph{}, _show_pos, _show_spans), do: "Paragraph"

  defp node_label(%Sentence{function: func, structure: struct}, _show_pos, _show_spans),
    do: "Sentence\\n#{func}\\n#{struct}"

  defp node_label(%Clause{type: type}, _show_pos, _show_spans), do: "Clause\\n#{type}"

  defp node_label(%NounPhrase{}, _show_pos, _show_spans), do: "NounPhrase"
  defp node_label(%VerbPhrase{}, _show_pos, _show_spans), do: "VerbPhrase"

  defp node_label(%Token{text: text, pos_tag: tag}, true, false),
    do: "#{text}\\n[#{tag}]"

  defp node_label(%Token{text: text}, false, false), do: text

  defp node_label(%Token{text: text, pos_tag: tag, span: span}, true, true),
    do: "#{text}\\n[#{tag}]\\n#{format_span(span)}"

  defp node_label(node, _show_pos, _show_spans), do: inspect(node)

  # Private: Node color based on type
  defp node_color(%Document{}), do: "lightblue"
  defp node_color(%Paragraph{}), do: "lightblue"
  defp node_color(%Sentence{}), do: "lightcyan"
  defp node_color(%Clause{}), do: "lightcyan"
  defp node_color(%NounPhrase{}), do: "lightgreen"
  defp node_color(%VerbPhrase{}), do: "lightyellow"
  defp node_color(%Token{pos_tag: :noun}), do: "palegreen"
  defp node_color(%Token{pos_tag: :verb}), do: "khaki"
  defp node_color(%Token{pos_tag: :adj}), do: "lightpink"
  defp node_color(%Token{}), do: "white"
  defp node_color(_), do: "lightgray"

  # Private: Entity color based on type
  defp entity_color(:PERSON), do: "lightblue"
  defp entity_color(:ORG), do: "lightgreen"
  defp entity_color(:LOC), do: "lightyellow"
  defp entity_color(:DATE), do: "lightpink"
  defp entity_color(:TIME), do: "lightpink"
  defp entity_color(_), do: "lightgray"

  # Private: Get children for traversal
  defp get_children(%Document{paragraphs: p}), do: p
  defp get_children(%Paragraph{sentences: s}), do: s
  defp get_children(%Sentence{main_clause: m, additional_clauses: a}), do: [m | a]

  defp get_children(%Clause{subject: s, predicate: p}),
    do: [s, p] |> Enum.reject(&is_nil/1)

  defp get_children(%NounPhrase{determiner: d, modifiers: m, head: h, post_modifiers: pm}),
    do: ([d | m] ++ [h | pm]) |> Enum.reject(&is_nil/1)

  defp get_children(%VerbPhrase{auxiliaries: a, head: h, complements: c, adverbials: ad}),
    do: a ++ [h] ++ c ++ ad

  defp get_children(_), do: []

  # Private: Extract tokens in order
  defp extract_tokens_ordered(node) do
    alias Nasty.Utils.Query
    Query.tokens(node)
  end

  # Private: Extract dependencies from node
  defp extract_dependencies(%Sentence{} = sentence) do
    # Try to extract from main clause
    extract_dependencies(sentence.main_clause)
  end

  defp extract_dependencies(%Document{} = doc) do
    doc
    |> Document.all_sentences()
    |> Enum.flat_map(&extract_dependencies/1)
  end

  defp extract_dependencies(_node) do
    # For now, return empty list
    # In a full implementation, this would extract Dependency nodes
    []
  end

  # Private: Find token index in list
  defp find_token_index(tokens, target) do
    Enum.find_index(tokens, fn token -> token == target end) || 0
  end

  # Private: Format span
  defp format_span(%{start_pos: {sl, sc}, end_pos: {el, ec}}) do
    "(#{sl}:#{sc}-#{el}:#{ec})"
  end

  defp format_span(_), do: ""

  # Private: Escape label for DOT format
  defp escape_label(text) do
    text
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  # Private: Convert to JSON structure
  defp to_json_structure(%Document{} = doc) do
    %{
      type: "Document",
      language: doc.language,
      metadata: doc.metadata,
      children: Enum.map(doc.paragraphs, &to_json_structure/1)
    }
  end

  defp to_json_structure(%Paragraph{} = para) do
    %{
      type: "Paragraph",
      children: Enum.map(para.sentences, &to_json_structure/1)
    }
  end

  defp to_json_structure(%Sentence{} = sent) do
    %{
      type: "Sentence",
      function: sent.function,
      structure: sent.structure,
      children:
        [sent.main_clause | sent.additional_clauses]
        |> Enum.map(&to_json_structure/1)
    }
  end

  defp to_json_structure(%Clause{} = clause) do
    children =
      [clause.subordinator, clause.subject, clause.predicate]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_json_structure/1)

    %{
      type: "Clause",
      clause_type: clause.type,
      children: children
    }
  end

  defp to_json_structure(%NounPhrase{} = np) do
    children =
      ([np.determiner | np.modifiers] ++ [np.head | np.post_modifiers])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_json_structure/1)

    %{
      type: "NounPhrase",
      children: children
    }
  end

  defp to_json_structure(%VerbPhrase{} = vp) do
    children =
      (vp.auxiliaries ++ [vp.head] ++ vp.complements ++ vp.adverbials)
      |> Enum.map(&to_json_structure/1)

    %{
      type: "VerbPhrase",
      children: children
    }
  end

  defp to_json_structure(%Token{} = token) do
    %{
      type: "Token",
      text: token.text,
      lemma: token.lemma,
      pos_tag: token.pos_tag,
      morphology: token.morphology
    }
  end

  defp to_json_structure(node) do
    %{type: "Unknown", value: inspect(node)}
  end
end
