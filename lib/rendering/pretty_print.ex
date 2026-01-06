defmodule Nasty.Rendering.PrettyPrint do
  @moduledoc """
  Pretty printing for AST nodes to aid debugging and visualization.

  Provides human-readable string representations of AST structures
  with proper indentation and highlighting of key information.

  ## Examples

      iex> Nasty.Rendering.PrettyPrint.print(document)
      \"\"\"
      Document (:en)
        Paragraph
          Sentence (declarative, simple)
            Clause (independent)
              Subject: NounPhrase
                Det: "the"
                Head: "cat" [noun]
              Predicate: VerbPhrase
                Head: "sat" [verb]
      \"\"\"

      iex> Nasty.Rendering.PrettyPrint.tree(document)
      \"\"\"
      Document
      ├── Paragraph
      │   └── Sentence
      │       └── Clause
      │           ├── NounPhrase
      │           │   ├── Token: the
      │           │   └── Token: cat
      │           └── VerbPhrase
      │               └── Token: sat
      \"\"\"
  """

  alias Nasty.AST.{
    AdjectivalPhrase,
    AdverbialPhrase,
    Clause,
    Document,
    NounPhrase,
    Paragraph,
    PrepositionalPhrase,
    Sentence,
    Token,
    VerbPhrase
  }

  @typedoc """
  Pretty print options.

  - `:indent` - Number of spaces per indent level (default: 2)
  - `:max_depth` - Maximum depth to print (default: nil = unlimited)
  - `:show_spans` - Whether to show position spans (default: false)
  - `:show_metadata` - Whether to show node metadata (default: false)
  - `:color` - Whether to use ANSI colors (default: false)
  """
  @type options :: [
          indent: pos_integer(),
          max_depth: pos_integer() | nil,
          show_spans: boolean(),
          show_metadata: boolean(),
          color: boolean()
        ]

  @doc """
  Pretty prints an AST node with indentation.

  ## Examples

      iex> Nasty.Rendering.PrettyPrint.print(document)
      "Document (:en)\\n  Paragraph\\n    ..."

      iex> Nasty.Rendering.PrettyPrint.print(document, indent: 4, max_depth: 2)
      "Document (:en)\\n    Paragraph\\n        ..."
  """
  @spec print(term(), options()) :: String.t()
  def print(node, opts \\ []) do
    indent_size = Keyword.get(opts, :indent, 2)
    max_depth = Keyword.get(opts, :max_depth)
    show_spans = Keyword.get(opts, :show_spans, false)
    show_metadata = Keyword.get(opts, :show_metadata, false)
    color = Keyword.get(opts, :color, false)

    do_inspect(node, 0, indent_size, max_depth, show_spans, show_metadata, color)
  end

  @doc """
  Pretty prints an AST node as a tree with box-drawing characters.

  ## Examples

      iex> Nasty.Rendering.PrettyPrint.tree(document)
      \"\"\"
      Document
      ├── Paragraph
      │   └── Sentence
      │       └── Clause
      \"\"\"
  """
  @spec tree(term(), options()) :: String.t()
  def tree(node, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth)
    color = Keyword.get(opts, :color, false)

    do_tree(node, "", true, 0, max_depth, color)
  end

  @doc """
  Prints summary statistics about an AST.

  ## Examples

      iex> Nasty.Rendering.PrettyPrint.stats(document)
      \"\"\"
      AST Statistics:
        Paragraphs: 3
        Sentences: 12
        Clauses: 15
        Tokens: 127
        Noun Phrases: 18
        Verb Phrases: 15
      \"\"\"
  """
  @spec stats(term()) :: String.t()
  def stats(node) do
    alias Nasty.Utils.Query

    lines = [
      "AST Statistics:",
      "  Paragraphs: #{Query.count(node, :paragraph)}",
      "  Sentences: #{Query.count(node, :sentence)}",
      "  Clauses: #{Query.count(node, :clause)}",
      "  Tokens: #{Query.count(node, :token)}",
      "  Noun Phrases: #{Query.count(node, :noun_phrase)}",
      "  Verb Phrases: #{Query.count(node, :verb_phrase)}"
    ]

    Enum.join(lines, "\n")
  end

  # Private: Indented inspection
  defp do_inspect(_node, depth, _indent_size, max_depth, _show_spans, _show_metadata, _color)
       when not is_nil(max_depth) and depth >= max_depth do
    "..."
  end

  defp do_inspect(
         %Document{} = doc,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header = colorize("Document", :cyan, color) <> " (#{doc.language})"

    header =
      if show_metadata and doc.metadata != %{},
        do: header <> " #{inspect(doc.metadata)}",
        else: header

    children =
      Enum.map(doc.paragraphs, fn para ->
        indent(indent_size, depth + 1) <>
          do_inspect(para, depth + 1, indent_size, max_depth, show_spans, show_metadata, color)
      end)

    [header | children] |> Enum.join("\n")
  end

  defp do_inspect(
         %Paragraph{} = para,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header = colorize("Paragraph", :cyan, color)

    children =
      Enum.map(para.sentences, fn sent ->
        indent(indent_size, depth + 1) <>
          do_inspect(sent, depth + 1, indent_size, max_depth, show_spans, show_metadata, color)
      end)

    [header | children] |> Enum.join("\n")
  end

  defp do_inspect(
         %Sentence{} = sent,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header =
      colorize("Sentence", :cyan, color) <>
        " (#{sent.function}, #{sent.structure})"

    main =
      indent(indent_size, depth + 1) <>
        do_inspect(
          sent.main_clause,
          depth + 1,
          indent_size,
          max_depth,
          show_spans,
          show_metadata,
          color
        )

    additional =
      Enum.map(sent.additional_clauses, fn clause ->
        indent(indent_size, depth + 1) <>
          do_inspect(clause, depth + 1, indent_size, max_depth, show_spans, show_metadata, color)
      end)

    [header, main | additional] |> Enum.join("\n")
  end

  defp do_inspect(
         %Clause{} = clause,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header = colorize("Clause", :cyan, color) <> " (#{clause.type})"

    parts = []

    # Subordinator
    parts =
      if clause.subordinator do
        sub =
          indent(indent_size, depth + 1) <>
            "Subordinator: " <>
            do_inspect(
              clause.subordinator,
              depth + 1,
              indent_size,
              max_depth,
              show_spans,
              show_metadata,
              color
            )

        [sub | parts]
      else
        parts
      end

    # Subject
    parts =
      if clause.subject do
        subj =
          indent(indent_size, depth + 1) <>
            "Subject: " <>
            do_inspect(
              clause.subject,
              depth + 1,
              indent_size,
              max_depth,
              show_spans,
              show_metadata,
              color
            )

        parts ++ [subj]
      else
        parts
      end

    # Predicate
    pred =
      indent(indent_size, depth + 1) <>
        "Predicate: " <>
        do_inspect(
          clause.predicate,
          depth + 1,
          indent_size,
          max_depth,
          show_spans,
          show_metadata,
          color
        )

    parts = parts ++ [pred]

    [header | parts] |> Enum.join("\n")
  end

  defp do_inspect(
         %NounPhrase{} = np,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header = colorize("NounPhrase", :green, color)

    parts = []

    # Determiner
    parts =
      if np.determiner do
        det =
          indent(indent_size, depth + 1) <>
            "Det: " <>
            do_inspect(np.determiner, 0, indent_size, max_depth, show_spans, show_metadata, color)

        [det | parts]
      else
        parts
      end

    # Modifiers
    parts =
      if np.modifiers != [] do
        mods =
          Enum.map(np.modifiers, fn mod ->
            indent(indent_size, depth + 1) <>
              "Mod: " <>
              do_inspect(mod, 0, indent_size, max_depth, show_spans, show_metadata, color)
          end)

        parts ++ mods
      else
        parts
      end

    # Head
    head =
      indent(indent_size, depth + 1) <>
        "Head: " <>
        do_inspect(np.head, 0, indent_size, max_depth, show_spans, show_metadata, color)

    parts = parts ++ [head]

    # Post-modifiers
    parts =
      if np.post_modifiers != [] do
        postmods =
          Enum.map(np.post_modifiers, fn mod ->
            indent(indent_size, depth + 1) <>
              do_inspect(mod, depth + 1, indent_size, max_depth, show_spans, show_metadata, color)
          end)

        parts ++ postmods
      else
        parts
      end

    [header | parts] |> Enum.join("\n")
  end

  defp do_inspect(
         %VerbPhrase{} = vp,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header = colorize("VerbPhrase", :yellow, color)

    parts = []

    # Auxiliaries
    parts =
      if vp.auxiliaries != [] do
        auxs =
          Enum.map(vp.auxiliaries, fn aux ->
            indent(indent_size, depth + 1) <>
              "Aux: " <>
              do_inspect(aux, 0, indent_size, max_depth, show_spans, show_metadata, color)
          end)

        parts ++ auxs
      else
        parts
      end

    # Head
    head =
      indent(indent_size, depth + 1) <>
        "Head: " <>
        do_inspect(vp.head, 0, indent_size, max_depth, show_spans, show_metadata, color)

    parts = parts ++ [head]

    # Complements
    parts =
      if vp.complements != [] do
        comps =
          Enum.map(vp.complements, fn comp ->
            indent(indent_size, depth + 1) <>
              "Complement: " <>
              do_inspect(
                comp,
                depth + 1,
                indent_size,
                max_depth,
                show_spans,
                show_metadata,
                color
              )
          end)

        parts ++ comps
      else
        parts
      end

    # Adverbials
    parts =
      if vp.adverbials != [] do
        advs =
          Enum.map(vp.adverbials, fn adv ->
            indent(indent_size, depth + 1) <>
              "Adverbial: " <>
              do_inspect(adv, depth + 1, indent_size, max_depth, show_spans, show_metadata, color)
          end)

        parts ++ advs
      else
        parts
      end

    [header | parts] |> Enum.join("\n")
  end

  defp do_inspect(
         %PrepositionalPhrase{} = pp,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    header = colorize("PrepositionalPhrase", :magenta, color)

    prep =
      indent(indent_size, depth + 1) <>
        "Prep: " <>
        do_inspect(pp.head, 0, indent_size, max_depth, show_spans, show_metadata, color)

    obj =
      indent(indent_size, depth + 1) <>
        "Object: " <>
        do_inspect(pp.object, depth + 1, indent_size, max_depth, show_spans, show_metadata, color)

    [header, prep, obj] |> Enum.join("\n")
  end

  defp do_inspect(
         %AdjectivalPhrase{} = ap,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    parts = [colorize("AdjectivalPhrase", :blue, color)]

    parts =
      if ap.intensifier do
        int =
          indent(indent_size, depth + 1) <>
            "Intensifier: " <>
            do_inspect(
              ap.intensifier,
              0,
              indent_size,
              max_depth,
              show_spans,
              show_metadata,
              color
            )

        parts ++ [int]
      else
        parts
      end

    head =
      indent(indent_size, depth + 1) <>
        "Head: " <>
        do_inspect(ap.head, 0, indent_size, max_depth, show_spans, show_metadata, color)

    Enum.join(parts ++ [head], "\n")
  end

  defp do_inspect(
         %AdverbialPhrase{} = advp,
         depth,
         indent_size,
         max_depth,
         show_spans,
         show_metadata,
         color
       ) do
    parts = [colorize("AdverbialPhrase", :blue, color)]

    parts =
      if advp.intensifier do
        int =
          indent(indent_size, depth + 1) <>
            "Intensifier: " <>
            do_inspect(
              advp.intensifier,
              0,
              indent_size,
              max_depth,
              show_spans,
              show_metadata,
              color
            )

        parts ++ [int]
      else
        parts
      end

    head =
      indent(indent_size, depth + 1) <>
        "Head: " <>
        do_inspect(advp.head, 0, indent_size, max_depth, show_spans, show_metadata, color)

    Enum.join(parts ++ [head], "\n")
  end

  defp do_inspect(
         %Token{} = token,
         _depth,
         _indent_size,
         _max_depth,
         show_spans,
         _show_metadata,
         color
       ) do
    text = colorize("\"#{token.text}\"", :white, color)
    tag = colorize("[#{token.pos_tag}]", :light_black, color)
    base = "#{text} #{tag}"

    if show_spans do
      span_str = format_span(token.span)
      "#{base} #{span_str}"
    else
      base
    end
  end

  defp do_inspect(node, _depth, _indent_size, _max_depth, _show_spans, _show_metadata, _color) do
    Kernel.inspect(node)
  end

  # Private: Tree-style rendering
  defp do_tree(_node, _prefix, _is_last, depth, max_depth, _color)
       when not is_nil(max_depth) and depth >= max_depth do
    "...\n"
  end

  defp do_tree(node, prefix, is_last, depth, max_depth, color) do
    connector = if is_last, do: "└── ", else: "├── "
    line = prefix <> connector <> node_label(node, color) <> "\n"

    children = get_children(node)

    child_prefix = prefix <> if(is_last, do: "    ", else: "│   ")

    child_lines =
      children
      |> Enum.with_index()
      |> Enum.map(fn {child, idx} ->
        is_last_child = idx == length(children) - 1
        do_tree(child, child_prefix, is_last_child, depth + 1, max_depth, color)
      end)

    line <> Enum.join(child_lines, "")
  end

  # Private: Get node label for tree
  defp node_label(%Document{language: lang}, color),
    do: colorize("Document", :cyan, color) <> " (#{lang})"

  defp node_label(%Paragraph{}, color), do: colorize("Paragraph", :cyan, color)

  defp node_label(%Sentence{function: func, structure: struct}, color),
    do: colorize("Sentence", :cyan, color) <> " (#{func}, #{struct})"

  defp node_label(%Clause{type: type}, color),
    do: colorize("Clause", :cyan, color) <> " (#{type})"

  defp node_label(%NounPhrase{}, color), do: colorize("NounPhrase", :green, color)
  defp node_label(%VerbPhrase{}, color), do: colorize("VerbPhrase", :yellow, color)

  defp node_label(%PrepositionalPhrase{}, color),
    do: colorize("PrepositionalPhrase", :magenta, color)

  defp node_label(%AdjectivalPhrase{}, color), do: colorize("AdjectivalPhrase", :blue, color)
  defp node_label(%AdverbialPhrase{}, color), do: colorize("AdverbialPhrase", :blue, color)

  defp node_label(%Token{text: text, pos_tag: tag}, color),
    do: colorize("Token", :white, color) <> ": #{text} [#{tag}]"

  defp node_label(node, _color), do: inspect(node)

  # Private: Get children for tree
  defp get_children(%Document{paragraphs: p}), do: p
  defp get_children(%Paragraph{sentences: s}), do: s
  defp get_children(%Sentence{main_clause: m, additional_clauses: a}), do: [m | a]

  defp get_children(%Clause{subject: s, predicate: p, subordinator: sub}),
    do: [sub, s, p] |> Enum.reject(&is_nil/1)

  defp get_children(%NounPhrase{determiner: d, modifiers: m, head: h, post_modifiers: pm}),
    do: ([d | m] ++ [h | pm]) |> Enum.reject(&is_nil/1)

  defp get_children(%VerbPhrase{auxiliaries: a, head: h, complements: c, adverbials: ad}),
    do: a ++ [h] ++ c ++ ad

  defp get_children(%PrepositionalPhrase{head: h, object: o}), do: [h, o]

  defp get_children(%AdjectivalPhrase{intensifier: i, head: h, complement: c}),
    do: [i, h, c] |> Enum.reject(&is_nil/1)

  defp get_children(%AdverbialPhrase{intensifier: i, head: h}),
    do: [i, h] |> Enum.reject(&is_nil/1)

  defp get_children(_), do: []

  # Private: Indent helper
  defp indent(size, level), do: String.duplicate(" ", size * level)

  # Private: Format span
  defp format_span(%{start_pos: {sl, sc}, end_pos: {el, ec}}) do
    "(#{sl}:#{sc}-#{el}:#{ec})"
  end

  defp format_span(_), do: ""

  # Private: ANSI color helper
  defp colorize(text, _color_name, false), do: text

  defp colorize(text, color_name, true) do
    code =
      case color_name do
        :cyan -> "\e[36m"
        :green -> "\e[32m"
        :yellow -> "\e[33m"
        :magenta -> "\e[35m"
        :blue -> "\e[34m"
        :white -> "\e[37m"
        :light_black -> "\e[90m"
        _ -> ""
      end

    code <> text <> "\e[0m"
  end
end
