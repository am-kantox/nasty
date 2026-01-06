defmodule Nasty.AST.Intent do
  @moduledoc """
  Intent node representing the semantic intent extracted from natural language.

  Intent is the bridge between natural language AST and code AST, capturing
  the action, target, and parameters needed for code generation.

  ## Intent Types

  - `:action` - Imperative command to perform an operation (e.g., "Sort the list")
  - `:query` - Interrogative question requiring a boolean answer (e.g., "Is X greater than Y?")
  - `:definition` - Declarative statement defining a value (e.g., "X is 5")
  - `:conditional` - Conditional statement with condition and consequence (e.g., "If X then Y")

  ## Examples

      # Action intent: "Sort the numbers"
      %Intent{
        type: :action,
        action: "sort",
        target: "numbers",
        arguments: [],
        confidence: 0.95
      }

      # Query intent: "Is the count greater than 10?"
      %Intent{
        type: :query,
        action: "is_greater_than",
        target: "count",
        arguments: [10],
        confidence: 0.90
      }

      # Definition intent: "The result equals X plus Y"
      %Intent{
        type: :definition,
        action: "assign",
        target: "result",
        arguments: ["+", "x", "y"],
        confidence: 0.88
      }
  """

  alias Nasty.AST.Node

  @typedoc """
  Intent type classification.

  - `:action` - Imperative command (function call)
  - `:query` - Interrogative question (assertion/test)
  - `:definition` - Declarative statement (variable assignment)
  - `:conditional` - Conditional logic (if/case expression)
  """
  @type intent_type :: :action | :query | :definition | :conditional

  @typedoc """
  Semantic constraint for filtering or predicates.

  Examples:
  - `{:comparison, :greater_than, 5}`
  - `{:equality, "admin"}`
  - `{:membership, ["active", "pending"]}`
  """
  @type constraint :: {atom(), term()} | {atom(), atom(), term()}

  @type t :: %__MODULE__{
          type: intent_type(),
          action: String.t(),
          target: String.t() | nil,
          arguments: [term()],
          constraints: [constraint()],
          confidence: float(),
          metadata: map(),
          language: Node.language(),
          span: Node.span()
        }

  @enforce_keys [:type, :action, :language, :span]
  defstruct [
    :type,
    :action,
    :language,
    :span,
    target: nil,
    arguments: [],
    constraints: [],
    confidence: 0.5,
    metadata: %{}
  ]

  @doc """
  Creates a new intent.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 15}, 15)
      iex> intent = Nasty.AST.Intent.new(:action, "sort", :en, span, target: "list")
      iex> intent.type
      :action
      iex> intent.action
      "sort"
      iex> intent.target
      "list"
  """
  @spec new(intent_type(), String.t(), Node.language(), Node.span(), keyword()) :: t()
  def new(type, action, language, span, opts \\ []) do
    %__MODULE__{
      type: type,
      action: action,
      language: language,
      span: span,
      target: Keyword.get(opts, :target),
      arguments: Keyword.get(opts, :arguments, []),
      constraints: Keyword.get(opts, :constraints, []),
      confidence: Keyword.get(opts, :confidence, 0.5),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Checks if intent represents an action (imperative command).

  ## Examples

      iex> intent = %Nasty.AST.Intent{type: :action, ...}
      iex> Nasty.AST.Intent.action?(intent)
      true
  """
  @spec action?(t()) :: boolean()
  def action?(%__MODULE__{type: :action}), do: true
  def action?(_), do: false

  @doc """
  Checks if intent represents a query (interrogative question).

  ## Examples

      iex> intent = %Nasty.AST.Intent{type: :query, ...}
      iex> Nasty.AST.Intent.query?(intent)
      true
  """
  @spec query?(t()) :: boolean()
  def query?(%__MODULE__{type: :query}), do: true
  def query?(_), do: false

  @doc """
  Checks if intent represents a definition (declarative statement).

  ## Examples

      iex> intent = %Nasty.AST.Intent{type: :definition, ...}
      iex> Nasty.AST.Intent.definition?(intent)
      true
  """
  @spec definition?(t()) :: boolean()
  def definition?(%__MODULE__{type: :definition}), do: true
  def definition?(_), do: false

  @doc """
  Checks if intent represents a conditional statement.

  ## Examples

      iex> intent = %Nasty.AST.Intent{type: :conditional, ...}
      iex> Nasty.AST.Intent.conditional?(intent)
      true
  """
  @spec conditional?(t()) :: boolean()
  def conditional?(%__MODULE__{type: :conditional}), do: true
  def conditional?(_), do: false

  @doc """
  Returns all arguments including target if present.

  ## Examples

      iex> intent = %Nasty.AST.Intent{target: "list", arguments: ["fn", "x"]}
      iex> Nasty.AST.Intent.all_arguments(intent)
      ["list", "fn", "x"]
  """
  @spec all_arguments(t()) :: [term()]
  def all_arguments(%__MODULE__{target: nil, arguments: args}), do: args

  def all_arguments(%__MODULE__{target: target, arguments: args}) do
    [target | args]
  end

  @doc """
  Adds a constraint to the intent.

  ## Examples

      iex> intent = %Nasty.AST.Intent{...}
      iex> intent = Nasty.AST.Intent.add_constraint(intent, {:comparison, :greater_than, 5})
      iex> intent.constraints
      [{:comparison, :greater_than, 5}]
  """
  @spec add_constraint(t(), constraint()) :: t()
  def add_constraint(%__MODULE__{constraints: constraints} = intent, constraint) do
    %{intent | constraints: [constraint | constraints]}
  end

  @doc """
  Sets the confidence score for the intent.

  ## Examples

      iex> intent = %Nasty.AST.Intent{...}
      iex> intent = Nasty.AST.Intent.set_confidence(intent, 0.95)
      iex> intent.confidence
      0.95
  """
  @spec set_confidence(t(), float()) :: t()
  def set_confidence(%__MODULE__{} = intent, confidence)
      when is_float(confidence) and confidence >= 0.0 and confidence <= 1.0 do
    %{intent | confidence: confidence}
  end

  @doc """
  Checks if intent has high confidence (>= 0.8).

  ## Examples

      iex> intent = %Nasty.AST.Intent{confidence: 0.9, ...}
      iex> Nasty.AST.Intent.high_confidence?(intent)
      true
  """
  @spec high_confidence?(t()) :: boolean()
  def high_confidence?(%__MODULE__{confidence: confidence}) do
    confidence >= 0.8
  end
end
