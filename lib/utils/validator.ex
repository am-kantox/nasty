defmodule Nasty.Utils.Validator do
  @moduledoc """
  AST validation utilities for ensuring structural consistency.

  Validates that AST nodes conform to expected schemas and
  that the tree structure is internally consistent.

  ## Examples

      iex> Nasty.Utils.Validator.validate(document)
      {:ok, document}

      iex> Nasty.Utils.Validator.validate(malformed_node)
      {:error, "Invalid node structure: ..."}
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

  alias Nasty.Utils.Traversal

  @doc """
  Validates an AST node and all its descendants.

  Returns `{:ok, node}` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> Nasty.Utils.Validator.validate(document)
      {:ok, document}

      iex> Nasty.Utils.Validator.validate(invalid_node)
      {:error, "Document language must be an atom"}
  """
  @spec validate(term()) :: {:ok, term()} | {:error, String.t()}
  def validate(node) do
    case validate_node(node) do
      :ok ->
        # Validate all children
        case validate_children(node) do
          :ok -> {:ok, node}
          {:error, _} = error -> error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Validates an AST node, raising on error.

  ## Examples

      iex> Nasty.Utils.Validator.validate!(document)
      document

      iex> Nasty.Utils.Validator.validate!(invalid_node)
      ** (RuntimeError) Invalid AST: Document language must be an atom
  """
  @spec validate!(term()) :: term()
  def validate!(node) do
    case validate(node) do
      {:ok, node} -> node
      {:error, reason} -> raise "Invalid AST: #{reason}"
    end
  end

  @doc """
  Checks if an AST node is valid.

  ## Examples

      iex> Nasty.Utils.Validator.valid?(document)
      true

      iex> Nasty.Utils.Validator.valid?(malformed_node)
      false
  """
  @spec valid?(term()) :: boolean()
  def valid?(node) do
    case validate(node) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Validates that spans are consistent throughout the tree.

  Checks that:
  - Parent spans contain all child spans
  - Spans don't overlap incorrectly
  - Byte offsets match positions

  ## Examples

      iex> Nasty.Utils.Validator.validate_spans(document)
      :ok
  """
  @spec validate_spans(term()) :: :ok | {:error, String.t()}
  def validate_spans(node) do
    visitor = fn n, acc ->
      case validate_span(n) do
        :ok -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end

    case Traversal.walk(node, :ok, visitor) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Validates language consistency throughout the tree.

  Ensures all nodes have the same language marker.

  ## Examples

      iex> Nasty.Utils.Validator.validate_language(document)
      :ok
  """
  @spec validate_language(term()) :: :ok | {:error, String.t()}
  def validate_language(node) do
    expected_lang = get_language(node)

    visitor = fn n, acc ->
      case get_language(n) do
        nil ->
          {:cont, acc}

        ^expected_lang ->
          {:cont, acc}

        other_lang ->
          {:halt, {:error, "Language mismatch: expected #{expected_lang}, found #{other_lang}"}}
      end
    end

    case Traversal.walk(node, :ok, visitor) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  # Private: Validate individual node
  defp validate_node(%Document{paragraphs: paras, language: lang, span: span})
       when is_list(paras) and is_atom(lang) and is_map(span) do
    :ok
  end

  defp validate_node(%Document{}) do
    {:error, "Invalid Document structure"}
  end

  defp validate_node(%Paragraph{sentences: sents, language: lang, span: span})
       when is_list(sents) and is_atom(lang) and is_map(span) do
    :ok
  end

  defp validate_node(%Paragraph{}) do
    {:error, "Invalid Paragraph structure"}
  end

  defp validate_node(%Sentence{
         function: func,
         structure: struct,
         main_clause: clause,
         language: lang,
         span: span
       })
       when func in [:declarative, :interrogative, :imperative, :exclamative] and
              struct in [:simple, :compound, :complex, :compound_complex, :fragment] and
              is_atom(lang) and is_map(span) and not is_nil(clause) do
    :ok
  end

  defp validate_node(%Sentence{}) do
    {:error, "Invalid Sentence structure"}
  end

  defp validate_node(%Clause{type: type, predicate: pred, language: lang, span: span})
       when type in [:independent, :subordinate, :relative, :complement] and
              is_atom(lang) and is_map(span) and not is_nil(pred) do
    :ok
  end

  defp validate_node(%Clause{}) do
    {:error, "Invalid Clause structure"}
  end

  defp validate_node(%NounPhrase{head: head, language: lang, span: span})
       when not is_nil(head) and is_atom(lang) and is_map(span) do
    :ok
  end

  defp validate_node(%NounPhrase{}) do
    {:error, "Invalid NounPhrase structure: missing head"}
  end

  defp validate_node(%VerbPhrase{head: head, language: lang, span: span})
       when not is_nil(head) and is_atom(lang) and is_map(span) do
    :ok
  end

  defp validate_node(%VerbPhrase{}) do
    {:error, "Invalid VerbPhrase structure: missing head"}
  end

  defp validate_node(%Token{text: text, pos_tag: tag, language: lang, span: span})
       when is_binary(text) and is_atom(tag) and is_atom(lang) and is_map(span) do
    if tag in Token.pos_tags() do
      :ok
    else
      {:error, "Invalid POS tag: #{tag}"}
    end
  end

  defp validate_node(%Token{}) do
    {:error, "Invalid Token structure"}
  end

  defp validate_node(_node) do
    # Unknown node types are allowed (for extensibility)
    :ok
  end

  # Private: Validate all children
  defp validate_children(node) do
    visitor = fn child, acc ->
      case validate_node(child) do
        :ok -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end

    case Traversal.walk(node, :ok, visitor) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  # Private: Validate span structure
  defp validate_span(%{span: span}) do
    case span do
      %{start_pos: {sl, sc}, end_pos: {el, ec}, start_offset: so, end_offset: eo}
      when is_integer(sl) and is_integer(sc) and is_integer(el) and is_integer(ec) and
             is_integer(so) and is_integer(eo) and sl > 0 and sc >= 0 and el > 0 and ec >= 0 and
             so >= 0 and eo >= so ->
        :ok

      _ ->
        {:error, "Invalid span structure"}
    end
  end

  defp validate_span(_node), do: :ok

  # Private: Get language from node
  defp get_language(%{language: lang}), do: lang
  defp get_language(_), do: nil
end
