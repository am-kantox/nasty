defmodule Nasty.Statistics.Parsing.PCFG do
  @moduledoc """
  Probabilistic Context-Free Grammar (PCFG) model for parsing.

  Implements the `Nasty.Statistics.Model` behaviour for statistical parsing
  with grammar rules learned from treebanks.

  ## Training

  PCFG models are trained on annotated treebanks (e.g., Universal Dependencies).
  The training process extracts grammar rules and estimates their probabilities
  from phrase structure trees.

  ## Parsing

  Uses the CYK algorithm to find the most likely parse tree for a sentence.
  The grammar is automatically converted to Chomsky Normal Form (CNF) for
  efficient parsing.

  ## Examples

      # Training
      training_data = load_treebank("data/train.conllu")
      model = PCFG.new()
      {:ok, trained} = PCFG.train(model, training_data, smoothing: 0.001)
      :ok = PCFG.save(trained, "priv/models/en/pcfg.model")

      # Parsing
      {:ok, model} = PCFG.load("priv/models/en/pcfg.model")
      tokens = [%Token{text: "the"}, %Token{text: "cat"}]
      {:ok, parse_tree} = PCFG.predict(model, tokens, [])
  """

  @behaviour Nasty.Statistics.Model

  alias Nasty.AST.Token
  alias Nasty.Statistics.Model
  alias Nasty.Statistics.Parsing.{CYKParser, Grammar}
  alias Nasty.Statistics.Parsing.Grammar.Rule

  defstruct [
    :rules,
    # List of all grammar rules
    :rule_index,
    # Index of rules by LHS for fast lookup
    :lexicon,
    # Word → POS tags mapping
    :non_terminals,
    # Set of all non-terminals
    :start_symbol,
    # Root symbol for parsing (default: :s)
    :smoothing_k,
    # Smoothing constant
    :language,
    # Language code
    :metadata
    # Training metadata
  ]

  @type t :: %__MODULE__{
          rules: [Rule.t()],
          rule_index: %{atom() => [Rule.t()]},
          lexicon: %{String.t() => [atom()]},
          non_terminals: MapSet.t(),
          start_symbol: atom(),
          smoothing_k: float(),
          language: atom(),
          metadata: map()
        }

  @doc """
  Creates a new untrained PCFG model.

  ## Options

  - `:start_symbol` - Root symbol (default: `:s`)
  - `:smoothing_k` - Smoothing constant (default: 0.001)
  - `:language` - Language code (default: `:en`)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      rules: [],
      rule_index: %{},
      lexicon: %{},
      non_terminals: MapSet.new(),
      start_symbol: Keyword.get(opts, :start_symbol, :s),
      smoothing_k: Keyword.get(opts, :smoothing_k, 0.001),
      language: Keyword.get(opts, :language, :en),
      metadata: %{}
    }
  end

  @impl true
  @doc """
  Trains the PCFG model on annotated phrase structure data.

  ## Training Data Format

  Training data should be a list of `{tokens, parse_tree}` tuples where:
  - `tokens` is a list of `%Token{}` structs
  - `parse_tree` is a hierarchical structure representing the syntax tree

  Alternatively, accepts raw grammar rules as `[{lhs, rhs, count}, ...]`.

  ## Options

  - `:smoothing` - Smoothing constant (overrides model setting)
  - `:cnf` - Convert to CNF (default: true)

  ## Returns

  `{:ok, trained_model}` with learned grammar rules
  """
  @spec train(t(), list(), keyword()) :: {:ok, t()} | {:error, term()}
  def train(model, training_data, opts \\ []) do
    smoothing = Keyword.get(opts, :smoothing, model.smoothing_k)
    convert_cnf = Keyword.get(opts, :cnf, true)

    # Extract rules from training data
    {rules, lexicon} = extract_rules(training_data, model.language)

    # Apply smoothing and normalization
    rules =
      rules
      |> Grammar.apply_smoothing(smoothing)
      |> Grammar.normalize_probabilities()

    # Optionally convert to CNF
    rules = if convert_cnf, do: Grammar.to_cnf(rules), else: rules

    # Build indices
    rule_index = Grammar.index_by_lhs(rules)
    non_terminals = Grammar.non_terminals(rules)

    trained_model = %{
      model
      | rules: rules,
        rule_index: rule_index,
        lexicon: lexicon,
        non_terminals: non_terminals,
        smoothing_k: smoothing,
        metadata: %{
          trained_at: DateTime.utc_now(),
          training_size: length(training_data),
          num_rules: length(rules),
          num_non_terminals: MapSet.size(non_terminals),
          vocab_size: map_size(lexicon),
          cnf: convert_cnf
        }
    }

    {:ok, trained_model}
  end

  @impl true
  @doc """
  Parses a sequence of tokens using the trained PCFG.

  ## Parameters

  - `model` - Trained PCFG model
  - `tokens` - List of `%Token{}` structs (should have POS tags)
  - `opts` - Options:
    - `:beam_width` - Beam search width (default: 10)
    - `:start_symbol` - Root symbol (default: model's start symbol)
    - `:n_best` - Return n-best parses (default: 1)

  ## Returns

  - `{:ok, parse_tree}` - Best parse tree
  - `{:ok, [parse_tree]}` - Multiple parse trees if `:n_best` > 1
  - `{:error, reason}` - Parsing failed
  """
  @spec predict(t(), [Token.t()], keyword()) :: {:ok, term()} | {:error, term()}
  def predict(model, tokens, opts \\ []) do
    beam_width = Keyword.get(opts, :beam_width, 10)
    start_symbol = Keyword.get(opts, :start_symbol, model.start_symbol)
    n_best = Keyword.get(opts, :n_best, 1)

    # Ensure tokens have POS tags (use them as terminal symbols if needed)
    tokens_with_pos = ensure_pos_tags(tokens)

    # Build lexical rules from tokens
    model_with_lexical = add_lexical_rules_for_tokens(model, tokens_with_pos)

    # Parse using CYK
    cyk_opts = [start_symbol: start_symbol, beam_width: beam_width]

    case CYKParser.parse(model_with_lexical, tokens_with_pos, cyk_opts) do
      {:ok, tree} when n_best == 1 ->
        {:ok, tree}

      {:ok, _tree} when n_best > 1 ->
        # Get n-best parses
        chart = CYKParser.build_chart(model_with_lexical, tokens_with_pos, beam_width)
        n = length(tokens_with_pos)
        trees = CYKParser.get_n_best_parses(chart, start_symbol, 0, n - 1, n_best)
        {:ok, trees}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  @doc """
  Saves the trained PCFG model to disk.
  """
  @spec save(t(), Path.t()) :: :ok | {:error, term()}
  def save(model, path) do
    binary = Model.serialize(model, model.metadata)

    case File.write(path, binary) do
      :ok -> :ok
      {:error, reason} -> {:error, {:file_write_failed, reason}}
    end
  end

  @impl true
  @doc """
  Loads a trained PCFG model from disk.
  """
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    case File.read(path) do
      {:ok, binary} ->
        case Model.deserialize(binary) do
          {:ok, model, _metadata} -> {:ok, model}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, {:file_read_failed, reason}}
    end
  end

  @impl true
  @doc """
  Returns model metadata.
  """
  @spec metadata(t()) :: map()
  def metadata(model), do: model.metadata

  ## Private Functions

  # Extract grammar rules from training data
  defp extract_rules(training_data, language) do
    # Two formats supported:
    # 1. Raw rules: [{lhs, rhs, count}, ...]
    # 2. Parse trees: [{tokens, tree}, ...]

    case List.first(training_data) do
      {lhs, rhs, count} when is_atom(lhs) and is_list(rhs) and is_number(count) ->
        # Format 1: Raw rules
        rules =
          Enum.map(training_data, fn {lhs, rhs, count} ->
            Rule.new(lhs, rhs, count, language)
          end)

        # Extract lexicon from lexical rules
        lexicon = build_lexicon(rules)

        {rules, lexicon}

      {_tokens, _tree} ->
        # Format 2: Parse trees - extract rules by counting occurrences
        rule_counts =
          training_data
          |> Enum.flat_map(fn {_tokens, tree} -> extract_rules_from_tree(tree) end)
          |> Enum.frequencies()

        # Convert counts to rules with probabilities
        rules =
          rule_counts
          |> Enum.map(fn {{lhs, rhs}, count} ->
            Rule.new(lhs, rhs, count, language)
          end)

        # Extract lexicon from lexical rules
        lexicon = build_lexicon(rules)

        {rules, lexicon}

      _ ->
        {[], %{}}
    end
  end

  # Extract rules from a parse tree by traversing it
  defp extract_rules_from_tree({lhs, children}) when is_atom(lhs) and is_list(children) do
    # Process each child to get RHS symbols and extract child rules
    {rhs, child_rules} =
      Enum.reduce(children, {[], []}, fn child, {rhs_acc, rules_acc} ->
        case child do
          # Non-terminal with children: {symbol, [...]}
          {symbol, grandchildren} when is_atom(symbol) and is_list(grandchildren) ->
            # Extract rules recursively from this subtree
            subtree_rules = extract_rules_from_tree(child)
            {[symbol | rhs_acc], rules_acc ++ subtree_rules}

          # Terminal: {symbol, "word"}
          {symbol, terminal} when is_atom(symbol) and is_binary(terminal) ->
            # Create lexical rule and add symbol to RHS
            lexical_rule = {symbol, [terminal]}
            {[symbol | rhs_acc], [lexical_rule | rules_acc]}

          # Direct atom
          atom when is_atom(atom) ->
            {[atom | rhs_acc], rules_acc}

          # Direct string (terminal)
          str when is_binary(str) ->
            {[str | rhs_acc], rules_acc}
        end
      end)

    # Reverse RHS to maintain order
    rhs = Enum.reverse(rhs)

    # Create rule for this node
    rule = {lhs, rhs}

    # Return this rule plus all child rules
    [rule | child_rules]
  end

  defp extract_rules_from_tree(_), do: []

  # Build word → POS tag mapping from lexical rules
  defp build_lexicon(rules) do
    rules
    |> Enum.filter(&Grammar.lexical_rule?/1)
    |> Enum.reduce(%{}, fn rule, acc ->
      [word] = rule.rhs
      tags = Map.get(acc, word, [])
      Map.put(acc, word, [rule.lhs | tags] |> Enum.uniq())
    end)
  end

  # Ensure all tokens have POS tags
  defp ensure_pos_tags(tokens) do
    Enum.map(tokens, fn token ->
      if token.pos_tag do
        token
      else
        # Fallback: use generic :word tag
        %{token | pos_tag: :word}
      end
    end)
  end

  # Add lexical rules for unknown words in input
  defp add_lexical_rules_for_tokens(model, tokens) do
    new_lexical_rules =
      tokens
      |> Enum.reject(fn token ->
        word = String.downcase(token.text)
        Map.has_key?(model.lexicon, word)
      end)
      |> Enum.map(fn token ->
        word = String.downcase(token.text)
        pos = token.pos_tag

        # Create lexical rule with smoothing probability
        Rule.new(pos, [word], model.smoothing_k, model.language)
      end)

    if new_lexical_rules == [] do
      model
    else
      # Add new rules to model
      all_rules = model.rules ++ new_lexical_rules
      rule_index = Grammar.index_by_lhs(all_rules)

      # Update lexicon
      new_lexicon =
        Enum.reduce(new_lexical_rules, model.lexicon, fn rule, lex ->
          [word] = rule.rhs
          tags = Map.get(lex, word, [])
          Map.put(lex, word, [rule.lhs | tags] |> Enum.uniq())
        end)

      %{model | rules: all_rules, rule_index: rule_index, lexicon: new_lexicon}
    end
  end

  @doc """
  Evaluates the model's parsing accuracy on test data.

  Computes bracketing precision, recall, and F1 score.

  ## Parameters

  - `model` - Trained PCFG model
  - `test_data` - List of `{tokens, gold_tree}` tuples
  - `opts` - Options passed to parser

  ## Returns

  Map with evaluation metrics:
  - `:precision` - Bracketing precision
  - `:recall` - Bracketing recall
  - `:f1` - Bracketing F1 score
  - `:exact_match` - Percentage of exact matches
  """
  @spec evaluate(t(), list(), keyword()) :: map()
  def evaluate(model, test_data, opts \\ []) do
    results =
      Enum.map(test_data, fn {tokens, gold_tree} ->
        case predict(model, tokens, opts) do
          {:ok, pred_tree} ->
            gold_brackets = extract_brackets_from_gold(gold_tree)
            pred_brackets = CYKParser.extract_brackets(pred_tree)

            {gold_brackets, pred_brackets}

          {:error, _} ->
            {[], []}
        end
      end)

    # Calculate metrics
    {all_gold, all_pred} =
      Enum.reduce(results, {[], []}, fn {gold, pred}, {g_acc, p_acc} ->
        {g_acc ++ gold, p_acc ++ pred}
      end)

    correct = MapSet.intersection(MapSet.new(all_gold), MapSet.new(all_pred)) |> MapSet.size()
    precision = if match?([_ | _], all_pred), do: correct / length(all_pred), else: 0.0
    recall = if match?([_ | _], all_gold), do: correct / length(all_gold), else: 0.0
    f1 = if precision + recall > 0, do: 2 * precision * recall / (precision + recall), else: 0.0

    exact_matches =
      Enum.count(results, fn {gold, pred} ->
        MapSet.equal?(MapSet.new(gold), MapSet.new(pred))
      end)

    exact_match_pct = exact_matches / length(test_data)

    %{
      precision: precision,
      recall: recall,
      f1: f1,
      exact_match: exact_match_pct,
      total: length(test_data)
    }
  end

  # Extract brackets from gold standard tree (format-specific)
  defp extract_brackets_from_gold(gold_tree) when is_map(gold_tree) do
    # Assuming similar structure to CYK parse trees
    CYKParser.extract_brackets(gold_tree)
  end

  defp extract_brackets_from_gold(_), do: []
end
