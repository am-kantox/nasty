defmodule Nasty.Statistics.Parsing.Grammar do
  @moduledoc """
  Grammar rule representation and manipulation for PCFGs.

  Provides data structures and operations for working with probabilistic
  context-free grammar rules.

  ## Grammar Rules

  A rule represents a production: `A → α` where:
  - `A` is a non-terminal (left-hand side)
  - `α` is a sequence of terminals and/or non-terminals (right-hand side)
  - Each rule has an associated probability

  ## Examples

      iex> rule = Grammar.Rule.new(:np, [:det, :noun], 0.35)
      %Grammar.Rule{lhs: :np, rhs: [:det, :noun], probability: 0.35}

      iex> Grammar.lexical_rule?(rule)
      false  # Not a lexical rule (no terminal symbols)
  """

  defmodule Rule do
    @moduledoc """
    Represents a single grammar rule with probability.

    ## Fields

    - `lhs` - Left-hand side non-terminal (atom)
    - `rhs` - Right-hand side (list of terminals/non-terminals)
    - `probability` - Rule probability (float, 0.0-1.0)
    - `language` - Language code (atom, e.g., `:en`)
    """

    @type symbol :: atom() | String.t()
    @type t :: %__MODULE__{
            lhs: atom(),
            rhs: [symbol()],
            probability: float(),
            language: atom()
          }

    defstruct [:lhs, :rhs, :probability, :language]

    @doc """
    Creates a new grammar rule.

    ## Examples

        iex> Rule.new(:np, [:det, :noun], 0.35, :en)
        %Rule{lhs: :np, rhs: [:det, :noun], probability: 0.35, language: :en}
    """
    @spec new(atom(), [symbol()], float(), atom()) :: t()
    def new(lhs, rhs, probability, language \\ :en) do
      %__MODULE__{
        lhs: lhs,
        rhs: rhs,
        probability: probability,
        language: language
      }
    end
  end

  @doc """
  Builds an index of rules by their left-hand side for fast lookup.

  ## Examples

      iex> rules = [
      ...>   Rule.new(:np, [:det, :noun], 0.35),
      ...>   Rule.new(:np, [:pron], 0.25),
      ...>   Rule.new(:vp, [:verb, :np], 0.45)
      ...> ]
      iex> index = Grammar.index_by_lhs(rules)
      iex> length(index[:np])
      2
  """
  @spec index_by_lhs([Rule.t()]) :: %{atom() => [Rule.t()]}
  def index_by_lhs(rules) do
    Enum.group_by(rules, & &1.lhs)
  end

  @doc """
  Checks if a rule is lexical (produces a terminal/word).

  A rule is lexical if its RHS contains exactly one element that is a string.

  ## Examples

      iex> Grammar.lexical_rule?(Rule.new(:noun, ["cat"], 0.01))
      true

      iex> Grammar.lexical_rule?(Rule.new(:np, [:det, :noun], 0.35))
      false
  """
  @spec lexical_rule?(Rule.t()) :: boolean()
  def lexical_rule?(%Rule{rhs: [word]}) when is_binary(word), do: true
  def lexical_rule?(_), do: false

  @doc """
  Checks if a rule is unary (A → B).

  ## Examples

      iex> Grammar.unary_rule?(Rule.new(:np, [:pron], 0.25))
      true

      iex> Grammar.unary_rule?(Rule.new(:np, [:det, :noun], 0.35))
      false
  """
  @spec unary_rule?(Rule.t()) :: boolean()
  def unary_rule?(%Rule{rhs: [symbol]}) when is_atom(symbol), do: true
  def unary_rule?(_), do: false

  @doc """
  Checks if a rule is binary (A → B C).

  ## Examples

      iex> Grammar.binary_rule?(Rule.new(:np, [:det, :noun], 0.35))
      true

      iex> Grammar.binary_rule?(Rule.new(:np, [:pron], 0.25))
      false
  """
  @spec binary_rule?(Rule.t()) :: boolean()
  def binary_rule?(%Rule{rhs: [s1, s2]}) when is_atom(s1) and is_atom(s2), do: true
  def binary_rule?(_), do: false

  @doc """
  Normalizes rule probabilities for rules with the same LHS.

  Ensures that P(A → α) for all rules with LHS = A sums to 1.0.

  ## Examples

      iex> rules = [
      ...>   Rule.new(:np, [:det, :noun], 35),  # Raw counts
      ...>   Rule.new(:np, [:pron], 25),
      ...>   Rule.new(:np, [:propn], 40)
      ...> ]
      iex> normalized = Grammar.normalize_probabilities(rules)
      iex> Enum.reduce(normalized, 0.0, fn r, acc -> acc + r.probability end)
      1.0
  """
  @spec normalize_probabilities([Rule.t()]) :: [Rule.t()]
  def normalize_probabilities(rules) do
    # Group by LHS
    grouped = Enum.group_by(rules, & &1.lhs)

    # Normalize each group
    Enum.flat_map(grouped, fn {_lhs, group} ->
      total = Enum.reduce(group, 0.0, fn r, acc -> acc + r.probability end)

      if total > 0 do
        Enum.map(group, fn rule ->
          %{rule | probability: rule.probability / total}
        end)
      else
        group
      end
    end)
  end

  @doc """
  Applies add-k smoothing to grammar rules.

  Adds a small constant `k` to each rule count before normalization
  to handle unseen productions.

  ## Examples

      iex> rules = [Rule.new(:np, [:det, :noun], 0.7), Rule.new(:np, [:pron], 0.3)]
      iex> smoothed = Grammar.apply_smoothing(rules, 0.001)
      iex> Enum.all?(smoothed, fn r -> r.probability > 0 end)
      true
  """
  @spec apply_smoothing([Rule.t()], float()) :: [Rule.t()]
  def apply_smoothing(rules, k \\ 0.001) do
    # Add k to each probability (treating them as counts)
    rules_with_k =
      Enum.map(rules, fn rule ->
        %{rule | probability: rule.probability + k}
      end)

    # Renormalize
    normalize_probabilities(rules_with_k)
  end

  @doc """
  Extracts all non-terminals used in the grammar.

  ## Examples

      iex> rules = [
      ...>   Rule.new(:np, [:det, :noun], 0.35),
      ...>   Rule.new(:vp, [:verb, :np], 0.45)
      ...> ]
      iex> Grammar.non_terminals(rules)
      MapSet.new([:np, :vp, :det, :noun, :verb])
  """
  @spec non_terminals([Rule.t()]) :: MapSet.t()
  def non_terminals(rules) do
    lhs_symbols = Enum.map(rules, & &1.lhs)

    rhs_symbols =
      rules
      |> Enum.flat_map(& &1.rhs)
      |> Enum.filter(&is_atom/1)

    MapSet.new(lhs_symbols ++ rhs_symbols)
  end

  @doc """
  Extracts all terminals (words) from lexical rules.

  ## Examples

      iex> rules = [
      ...>   Rule.new(:det, ["the"], 0.5),
      ...>   Rule.new(:noun, ["cat"], 0.3)
      ...> ]
      iex> Grammar.terminals(rules)
      MapSet.new(["the", "cat"])
  """
  @spec terminals([Rule.t()]) :: MapSet.t()
  def terminals(rules) do
    rules
    |> Enum.filter(&lexical_rule?/1)
    |> Enum.flat_map(& &1.rhs)
    |> MapSet.new()
  end

  @doc """
  Converts the grammar to Chomsky Normal Form (CNF).

  CNF requires:
  - All rules are either binary (A → B C) or lexical (A → word)
  - No unary rules (except to terminals)
  - No epsilon productions

  This is required for CYK parsing.

  ## Implementation

  1. Eliminate epsilon productions
  2. Eliminate unary rules (A → B) by substitution
  3. Convert long rules (A → B C D) into binary: A → B X, X → C D
  4. Convert mixed terminal/non-terminal rules

  ## Examples

      iex> rules = [Rule.new(:s, [:np, :vp, :pp], 0.8)]
      iex> cnf_rules = Grammar.to_cnf(rules)
      iex> Enum.all?(cnf_rules, fn r -> binary_rule?(r) or lexical_rule?(r) end)
      true
  """
  @spec to_cnf([Rule.t()]) :: [Rule.t()]
  def to_cnf(rules) do
    rules
    |> eliminate_unary_rules()
    |> binarize_rules()
    |> extract_terminals_from_mixed_rules()
  end

  # Eliminate unary non-terminal rules by substitution
  defp eliminate_unary_rules(rules) do
    # Separate unary and non-unary rules
    {unary, non_unary} = Enum.split_with(rules, &unary_rule?/1)

    # For each unary rule A → B, replace with A → α for all B → α
    expanded =
      Enum.flat_map(unary, fn %Rule{lhs: a, rhs: [b]} = unary_rule ->
        # Find all rules with B on LHS
        b_rules = Enum.filter(non_unary, fn r -> r.lhs == b end)

        # Create new rules A → α with combined probability
        Enum.map(b_rules, fn b_rule ->
          %Rule{
            lhs: a,
            rhs: b_rule.rhs,
            probability: unary_rule.probability * b_rule.probability,
            language: unary_rule.language
          }
        end)
      end)

    non_unary ++ expanded
  end

  # Convert rules with RHS length > 2 into binary rules
  defp binarize_rules(rules) do
    Enum.flat_map(rules, fn rule ->
      case length(rule.rhs) do
        n when n <= 2 ->
          [rule]

        n when n > 2 ->
          # Split: A → B C D E becomes A → B X1, X1 → C X2, X2 → D E
          binarize_long_rule(rule)
      end
    end)
  end

  defp binarize_long_rule(%Rule{lhs: lhs, rhs: rhs, probability: prob, language: lang}) do
    # Generate unique non-terminal names
    [first, second | rest] = rhs
    new_nt = String.to_atom("#{lhs}_#{first}_#{second}")

    # Create first binary rule
    first_rule = Rule.new(lhs, [first, new_nt], prob, lang)

    # Recursively binarize the rest
    rest_rule = Rule.new(new_nt, [second | rest], 1.0, lang)
    rest_rules = binarize_rules([rest_rule])

    [first_rule | rest_rules]
  end

  # Extract terminals from mixed rules (A → B "word") into pure rules
  defp extract_terminals_from_mixed_rules(rules) do
    Enum.flat_map(rules, fn rule ->
      # Check if RHS has both terminals and non-terminals
      {terminals, non_terminals} = Enum.split_with(rule.rhs, &is_binary/1)

      if terminals != [] and non_terminals != [] do
        # Create new non-terminal for each terminal
        terminal_rules =
          Enum.map(terminals, fn term ->
            new_nt = String.to_atom("word_#{term}")
            Rule.new(new_nt, [term], 1.0, rule.language)
          end)

        # Replace terminals in original rule with new non-terminals
        new_rhs =
          Enum.map(rule.rhs, fn symbol ->
            if is_binary(symbol) do
              String.to_atom("word_#{symbol}")
            else
              symbol
            end
          end)

        new_rule = %{rule | rhs: new_rhs}

        [new_rule | terminal_rules]
      else
        [rule]
      end
    end)
  end
end
