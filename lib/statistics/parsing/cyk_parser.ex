defmodule Nasty.Statistics.Parsing.CYKParser do
  @moduledoc """
  CYK (Cocke-Younger-Kasami) parsing algorithm for PCFGs.

  Implements bottom-up chart parsing with dynamic programming to find
  the highest probability parse tree for a given sentence.

  ## Algorithm

  The CYK algorithm uses a chart (2D table) where `chart[i][j]` stores
  all possible parse trees for the span from word i to word j.

  1. Initialize bottom row with lexical rules (words)
  2. For each span length (2 to n):
     - For each possible split point k:
       - Try combining trees from [i,k] and [k+1,j]
       - If a binary rule A → B C exists, create new tree for A
  3. Return highest probability tree spanning entire sentence

  ## Complexity

  Time: O(n³ × |G|) where n = sentence length, |G| = grammar size
  Space: O(n² × |G|)

  ## Examples

      iex> grammar = PCFG.new(...)
      iex> tokens = [%Token{text: "the"}, %Token{text: "cat"}]
      iex> {:ok, parse_tree} = CYKParser.parse(grammar, tokens)
  """

  alias Nasty.AST.Token
  alias Nasty.Statistics.Parsing.Grammar
  alias Nasty.Statistics.Parsing.Grammar.Rule

  @type parse_tree :: %{
          label: atom(),
          probability: float(),
          children: [parse_tree() | Token.t()],
          span: {non_neg_integer(), non_neg_integer()},
          rule: Rule.t() | nil
        }

  @type chart_entry :: {atom(), parse_tree()}
  @type chart :: %{{non_neg_integer(), non_neg_integer()} => [chart_entry()]}

  @doc """
  Parses a sequence of tokens using the CYK algorithm.

  Returns the highest probability parse tree, or an error if no parse exists.

  ## Parameters

  - `grammar` - PCFG model with rules in CNF
  - `tokens` - List of tokens to parse
  - `opts` - Options:
    - `:start_symbol` - Root non-terminal (default: `:s`)
    - `:beam_width` - Max entries per chart cell (default: 10, 0 = unlimited)

  ## Returns

  - `{:ok, parse_tree}` - Successful parse
  - `{:error, reason}` - No valid parse found
  """
  @spec parse(map(), [Token.t()], keyword()) :: {:ok, parse_tree()} | {:error, term()}
  def parse(grammar, tokens, opts \\ []) do
    start_symbol = Keyword.get(opts, :start_symbol, :s)
    beam_width = Keyword.get(opts, :beam_width, 10)

    n = length(tokens)

    if n == 0 do
      {:error, :empty_input}
    else
      # Build CYK chart
      chart = build_chart(grammar, tokens, beam_width)

      # Extract best parse from chart
      case get_best_parse(chart, start_symbol, 0, n - 1) do
        nil -> {:error, :no_parse}
        tree -> {:ok, tree}
      end
    end
  end

  @doc """
  Builds the CYK parsing chart using dynamic programming.

  ## Implementation

  1. Fill diagonal with lexical rules (single words)
  2. For increasing span lengths:
     - Try all split points
     - Apply binary rules to combine smaller spans
  3. Keep only highest probability parses (beam search)
  """
  @spec build_chart(map(), [Token.t()], non_neg_integer()) :: chart()
  def build_chart(grammar, tokens, beam_width) do
    n = length(tokens)
    chart = %{}

    # Step 1: Initialize with lexical rules (span length 1)
    chart =
      Enum.reduce(0..(n - 1), chart, fn i, acc ->
        token = Enum.at(tokens, i)
        lexical_entries = get_lexical_parses(grammar, token, i)
        # Also apply unary rules to lexical entries
        with_unary = apply_unary_closure(grammar, lexical_entries, i, i)
        put_chart_entries(acc, i, i, with_unary, beam_width)
      end)

    # Step 2: Fill chart for increasing span lengths
    Enum.reduce(2..n//1, chart, fn length, chart_acc ->
      Enum.reduce(0..(n - length)//1, chart_acc, fn i, chart_acc2 ->
        j = i + length - 1

        # Try all split points k in [i, j-1]
        binary_entries =
          for k <- i..(j - 1)//1,
              left_entry <- get_chart_entries(chart_acc2, i, k),
              right_entry <- get_chart_entries(chart_acc2, k + 1, j),
              {label, tree} <- apply_binary_rules(grammar, left_entry, right_entry, i, j) do
            {label, tree}
          end

        # Apply unary rules to entries we just created from binary rules
        # Need to do this iteratively until no new entries are generated
        with_unary = apply_unary_closure(grammar, binary_entries, i, j)

        put_chart_entries(chart_acc2, i, j, with_unary, beam_width)
      end)
    end)
  end

  # Get lexical parse trees for a single token
  defp get_lexical_parses(grammar, token, position) do
    word = String.downcase(token.text)

    # Find all lexical rules that produce this word
    grammar.rule_index
    |> Enum.flat_map(fn {lhs, rules} ->
      Enum.filter(rules, fn rule ->
        Grammar.lexical_rule?(rule) and hd(rule.rhs) == word
      end)
      |> Enum.map(fn rule ->
        tree = %{
          label: lhs,
          probability: rule.probability,
          children: [token],
          span: {position, position},
          rule: rule
        }

        {lhs, tree}
      end)
    end)
  end

  # Apply binary grammar rules to combine two parse trees
  defp apply_binary_rules(grammar, {left_label, left_tree}, {right_label, right_tree}, i, j) do
    # Find all rules A → B C where B = left_label, C = right_label
    grammar.rule_index
    |> Enum.flat_map(fn {lhs, rules} ->
      Enum.filter(rules, fn rule ->
        match?(%Rule{rhs: [^left_label, ^right_label]}, rule)
      end)
      |> Enum.map(fn rule ->
        # Combined probability: P(rule) * P(left) * P(right)
        prob = rule.probability * left_tree.probability * right_tree.probability

        tree = %{
          label: lhs,
          probability: prob,
          children: [left_tree, right_tree],
          span: {i, j},
          rule: rule
        }

        {lhs, tree}
      end)
    end)
  end

  # Apply unary grammar rules to a single parse tree
  defp apply_unary_rules(grammar, {child_label, child_tree}, i, j) do
    # Find all rules A → B where B = child_label
    grammar.rule_index
    |> Enum.flat_map(fn {lhs, rules} ->
      Enum.filter(rules, fn rule ->
        # Unary rule: single non-terminal on RHS
        match?(%Rule{rhs: [^child_label]}, rule) and is_atom(child_label)
      end)
      |> Enum.map(fn rule ->
        # Combined probability: P(rule) * P(child)
        prob = rule.probability * child_tree.probability

        tree = %{
          label: lhs,
          probability: prob,
          children: [child_tree],
          span: {i, j},
          rule: rule
        }

        {lhs, tree}
      end)
    end)
  end

  # Apply unary rules repeatedly until no new entries are generated (closure)
  defp apply_unary_closure(grammar, entries, i, j) do
    apply_unary_closure_iter(grammar, entries, MapSet.new(), i, j)
  end

  defp apply_unary_closure_iter(grammar, entries, seen_labels, i, j) do
    # Apply unary rules to all current entries
    new_entries =
      Enum.flat_map(entries, fn entry ->
        apply_unary_rules(grammar, entry, i, j)
      end)
      # Filter out entries we've already seen (to prevent infinite loops)
      |> Enum.reject(fn {label, _tree} -> MapSet.member?(seen_labels, label) end)

    if new_entries == [] do
      # No new entries, we're done
      entries
    else
      # Add new entries and continue
      all_entries = entries ++ new_entries

      new_seen =
        Enum.reduce(entries, seen_labels, fn {label, _}, acc -> MapSet.put(acc, label) end)

      apply_unary_closure_iter(grammar, all_entries, new_seen, i, j)
    end
  end

  # Store entries in chart cell, keeping only top-k by probability (beam search)
  defp put_chart_entries(chart, i, j, entries, beam_width) do
    # Group by label and keep only best parse for each label
    grouped =
      entries
      |> Enum.group_by(fn {label, _tree} -> label end)
      |> Enum.map(fn {label, group} ->
        # Get highest probability tree for this label
        {^label, best_tree} = Enum.max_by(group, fn {_lbl, tree} -> tree.probability end)
        {label, best_tree}
      end)

    # Apply beam search: keep only top-k entries overall
    pruned =
      if beam_width > 0 and length(grouped) > beam_width do
        grouped
        |> Enum.sort_by(fn {_label, tree} -> tree.probability end, :desc)
        |> Enum.take(beam_width)
      else
        grouped
      end

    Map.put(chart, {i, j}, pruned)
  end

  # Retrieve all entries for chart cell [i, j]
  defp get_chart_entries(chart, i, j) do
    Map.get(chart, {i, j}, [])
  end

  # Get best parse tree for a specific non-terminal and span
  defp get_best_parse(chart, label, i, j) do
    chart
    |> get_chart_entries(i, j)
    |> Enum.filter(fn {lbl, _tree} -> lbl == label end)
    |> case do
      [] -> nil
      [{^label, tree}] -> tree
      matches -> Enum.max_by(matches, fn {_lbl, tree} -> tree.probability end) |> elem(1)
    end
  end

  @doc """
  Extracts all possible parse trees from the chart.

  Returns all trees (not just the best one) for the given span and label.
  Useful for n-best parsing.

  ## Parameters

  - `chart` - Completed CYK chart
  - `label` - Non-terminal to extract
  - `i` - Start position
  - `j` - End position
  - `n` - Number of best parses to return (default: 1)
  """
  @spec get_n_best_parses(chart(), atom(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          [parse_tree()]
  def get_n_best_parses(chart, label, i, j, n \\ 1) do
    chart
    |> get_chart_entries(i, j)
    |> Enum.filter(fn {lbl, _tree} -> lbl == label end)
    |> Enum.map(fn {_lbl, tree} -> tree end)
    |> Enum.sort_by(& &1.probability, :desc)
    |> Enum.take(n)
  end

  @doc """
  Converts a parse tree to a bracketed string representation.

  Useful for evaluation and debugging.

  ## Examples

      iex> tree = %{label: :np, children: [...]}
      iex> CYKParser.to_brackets(tree)
      "(NP (DET the) (NOUN cat))"
  """
  @spec to_brackets(parse_tree()) :: String.t()
  def to_brackets(%{label: label, children: children}) do
    label_str = label |> to_string() |> String.upcase()

    if Enum.all?(children, &is_struct(&1, Token)) do
      # Leaf node (lexical)
      words = Enum.map_join(children, " ", & &1.text)
      "(#{label_str} #{words})"
    else
      # Internal node
      children_strs = Enum.map(children, &to_brackets/1)
      "(#{label_str} #{Enum.join(children_strs, " ")})"
    end
  end

  def to_brackets(%Token{text: text}), do: text

  @doc """
  Extracts bracket pairs from a parse tree for evaluation.

  Returns a list of `{label, start_pos, end_pos}` tuples representing
  all constituents in the tree.

  ## Examples

      iex> tree = parse_tree_for("the cat sat")
      iex> CYKParser.extract_brackets(tree)
      [{:s, 0, 2}, {:np, 0, 1}, {:vp, 2, 2}, ...]
  """
  @spec extract_brackets(parse_tree()) :: [{atom(), non_neg_integer(), non_neg_integer()}]
  def extract_brackets(%{label: label, span: {i, j}, children: children}) do
    # Add this constituent
    this_bracket = {label, i, j}

    # Recursively extract from children
    child_brackets =
      children
      |> Enum.filter(&is_map/1)
      |> Enum.flat_map(&extract_brackets/1)

    [this_bracket | child_brackets]
  end

  def extract_brackets(%Token{}), do: []

  @doc """
  Computes log probability of a parse tree.

  Sum of log probabilities of all rules used in the tree.
  More numerically stable than multiplying probabilities.

  ## Examples

      iex> tree = %{probability: 0.001, children: [...]}
      iex> CYKParser.log_probability(tree)
      -6.907755278982137  # log(0.001)
  """
  @spec log_probability(parse_tree()) :: float()
  def log_probability(%{probability: prob}) do
    :math.log(prob)
  end
end
