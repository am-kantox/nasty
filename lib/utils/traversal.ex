defmodule Nasty.Utils.Traversal do
  @moduledoc """
  AST traversal utilities using the visitor pattern.

  This module provides flexible tree traversal for AST nodes, supporting
  both depth-first and breadth-first traversal strategies.

  ## Visitor Pattern

  The visitor pattern allows you to define custom behavior for each node type
  without modifying the node modules themselves.

  ## Examples

      # Collect all tokens
      iex> visitor = fn
      ...>   %Nasty.AST.Token{} = token, acc -> {:cont, [token | acc]}
      ...>   _node, acc -> {:cont, acc}
      ...> end
      iex> Nasty.Utils.Traversal.walk(document, [], visitor)
      [token1, token2, ...]

      # Find first noun
      iex> visitor = fn
      ...>   %Nasty.AST.Token{pos_tag: :noun} = token, _acc -> {:halt, token}
      ...>   _node, acc -> {:cont, acc}
      ...> end
      iex> Nasty.Utils.Traversal.walk(document, nil, visitor)
      %Nasty.AST.Token{text: "cat", ...}
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
  Visitor function that processes nodes during traversal.

  The function receives the current node and an accumulator, and returns:
  - `{:cont, new_acc}` - Continue traversal with updated accumulator
  - `{:halt, result}` - Stop traversal and return result
  - `{:skip, new_acc}` - Skip children of this node but continue traversal
  """
  @type visitor(acc) :: (term(), acc -> {:cont, acc} | {:halt, term()} | {:skip, acc})

  @doc """
  Walks the AST using depth-first pre-order traversal.

  Visits parent nodes before their children.

  ## Examples

      iex> count_tokens = fn
      ...>   %Nasty.AST.Token{}, acc -> {:cont, acc + 1}
      ...>   _node, acc -> {:cont, acc}
      ...> end
      iex> Nasty.Utils.Traversal.walk(document, 0, count_tokens)
      42
  """
  @spec walk(term(), acc, visitor(acc)) :: acc when acc: term()
  def walk(node, acc, visitor) do
    case visitor.(node, acc) do
      {:cont, new_acc} ->
        walk_children(node, new_acc, visitor)

      {:halt, result} ->
        result

      {:skip, new_acc} ->
        new_acc
    end
  end

  @doc """
  Walks the AST using depth-first post-order traversal.

  Visits children before their parent nodes.

  ## Examples

      iex> collect_depths = fn
      ...>   %Nasty.AST.Token{}, depth -> {:cont, [depth]}
      ...>   _node, depths -> {:cont, depths}
      ...> end
      iex> Nasty.Utils.Traversal.walk_post(document, 0, collect_depths)
      [3, 3, 2, 3, 3, 2, 1, ...]
  """
  @spec walk_post(term(), acc, visitor(acc)) :: acc when acc: term()
  def walk_post(node, acc, visitor) do
    new_acc = walk_children_post(node, acc, visitor)

    case visitor.(node, new_acc) do
      {:cont, result} -> result
      {:halt, result} -> result
      {:skip, result} -> result
    end
  end

  @doc """
  Performs breadth-first traversal of the AST.

  Visits all nodes at depth N before visiting nodes at depth N+1.

  ## Examples

      iex> visitor = fn node, acc -> {:cont, [node | acc]} end
      iex> nodes = Nasty.Utils.Traversal.walk_breadth(document, [], visitor)
      iex> Enum.reverse(nodes)
      [document, paragraph1, paragraph2, sentence1, sentence2, ...]
  """
  @spec walk_breadth(term(), acc, visitor(acc)) :: acc when acc: term()
  def walk_breadth(node, acc, visitor) do
    walk_breadth_queue([node], acc, visitor)
  end

  defp walk_breadth_queue([], acc, _visitor), do: acc

  defp walk_breadth_queue([node | rest], acc, visitor) do
    case visitor.(node, acc) do
      {:cont, new_acc} ->
        children = get_children(node)
        walk_breadth_queue(rest ++ children, new_acc, visitor)

      {:halt, result} ->
        result

      {:skip, new_acc} ->
        walk_breadth_queue(rest, new_acc, visitor)
    end
  end

  @doc """
  Collects all nodes matching a predicate.

  ## Examples

      iex> is_noun? = fn
      ...>   %Nasty.AST.Token{pos_tag: :noun} -> true
      ...>   _ -> false
      ...> end
      iex> Nasty.Utils.Traversal.collect(document, is_noun?)
      [token1, token2, ...]
  """
  @spec collect(term(), (term() -> boolean())) :: [term()]
  def collect(node, predicate) do
    visitor = fn
      n, acc ->
        if predicate.(n) do
          {:cont, [n | acc]}
        else
          {:cont, acc}
        end
    end

    node
    |> walk([], visitor)
    |> Enum.reverse()
  end

  @doc """
  Finds the first node matching a predicate.

  Returns `nil` if no matching node is found.

  ## Examples

      iex> Nasty.Utils.Traversal.find(document, &match?(%Nasty.AST.Token{pos_tag: :verb}, &1))
      %Nasty.AST.Token{text: "runs", pos_tag: :verb, ...}
  """
  @spec find(term(), (term() -> boolean())) :: term() | nil
  def find(node, predicate) do
    visitor = fn
      n, _acc ->
        if predicate.(n) do
          {:halt, n}
        else
          {:cont, nil}
        end
    end

    walk(node, nil, visitor)
  end

  @doc """
  Maps a function over all nodes, returning a transformed tree.

  ## Examples

      iex> lowercase = fn
      ...>   %Nasty.AST.Token{} = token -> %{token | text: String.downcase(token.text)}
      ...>   node -> node
      ...> end
      iex> Nasty.Utils.Traversal.map(document, lowercase)
      %Nasty.AST.Document{...}
  """
  @spec map(term(), (term() -> term())) :: term()
  def map(node, mapper) do
    transformed = mapper.(node)
    map_children(transformed, mapper)
  end

  @doc """
  Reduces the AST to a single value.

  Similar to `Enum.reduce/3` but for tree structures.

  ## Examples

      iex> count = fn _node, acc -> acc + 1 end
      iex> Nasty.Utils.Traversal.reduce(document, 0, count)
      127  # Total number of nodes
  """
  @spec reduce(term(), acc, (term(), acc -> acc)) :: acc when acc: term()
  def reduce(node, acc, reducer) do
    visitor = fn n, a -> {:cont, reducer.(n, a)} end
    walk(node, acc, visitor)
  end

  # Private: Walk children in pre-order
  defp walk_children(node, acc, visitor) do
    Enum.reduce(get_children(node), acc, fn child, child_acc ->
      case walk(child, child_acc, visitor) do
        {:halt, _} = result -> throw(result)
        result -> result
      end
    end)
  catch
    {:halt, result} -> result
  end

  # Private: Walk children in post-order
  defp walk_children_post(node, acc, visitor) do
    Enum.reduce(get_children(node), acc, fn child, child_acc ->
      case walk_post(child, child_acc, visitor) do
        {:halt, _} = result -> throw(result)
        result -> result
      end
    end)
  catch
    {:halt, result} -> result
  end

  # Private: Map function over children
  defp map_children(%Document{} = doc, mapper) do
    %{doc | paragraphs: Enum.map(doc.paragraphs, &map(&1, mapper))}
  end

  defp map_children(%Paragraph{} = para, mapper) do
    %{para | sentences: Enum.map(para.sentences, &map(&1, mapper))}
  end

  defp map_children(%Sentence{} = sent, mapper) do
    %{
      sent
      | main_clause: map(sent.main_clause, mapper),
        additional_clauses: Enum.map(sent.additional_clauses, &map(&1, mapper))
    }
  end

  defp map_children(%Clause{} = clause, mapper) do
    %{
      clause
      | subject: if(clause.subject, do: map(clause.subject, mapper), else: nil),
        predicate: map(clause.predicate, mapper),
        subordinator: if(clause.subordinator, do: map(clause.subordinator, mapper), else: nil)
    }
  end

  defp map_children(%NounPhrase{} = np, mapper) do
    %{
      np
      | determiner: if(np.determiner, do: map(np.determiner, mapper), else: nil),
        modifiers: Enum.map(np.modifiers, &map(&1, mapper)),
        head: map(np.head, mapper),
        post_modifiers: Enum.map(np.post_modifiers, &map(&1, mapper))
    }
  end

  defp map_children(%VerbPhrase{} = vp, mapper) do
    %{
      vp
      | auxiliaries: Enum.map(vp.auxiliaries, &map(&1, mapper)),
        head: map(vp.head, mapper),
        complements: Enum.map(vp.complements, &map(&1, mapper)),
        adverbials: Enum.map(vp.adverbials, &map(&1, mapper))
    }
  end

  defp map_children(%PrepositionalPhrase{} = pp, mapper) do
    %{
      pp
      | head: map(pp.head, mapper),
        object: map(pp.object, mapper)
    }
  end

  defp map_children(%AdjectivalPhrase{} = ap, mapper) do
    %{
      ap
      | intensifier: if(ap.intensifier, do: map(ap.intensifier, mapper), else: nil),
        head: map(ap.head, mapper),
        complement: if(ap.complement, do: map(ap.complement, mapper), else: nil)
    }
  end

  defp map_children(%AdverbialPhrase{} = advp, mapper) do
    %{
      advp
      | intensifier: if(advp.intensifier, do: map(advp.intensifier, mapper), else: nil),
        head: map(advp.head, mapper)
    }
  end

  defp map_children(%Token{} = token, _mapper), do: token
  defp map_children(node, _mapper), do: node

  # Private: Get immediate children of a node
  defp get_children(%Document{paragraphs: paragraphs}), do: paragraphs
  defp get_children(%Paragraph{sentences: sentences}), do: sentences

  defp get_children(%Sentence{main_clause: main, additional_clauses: additional}) do
    [main | additional]
  end

  defp get_children(%Clause{subject: subj, predicate: pred, subordinator: sub}) do
    [sub, subj, pred] |> Enum.reject(&is_nil/1)
  end

  defp get_children(%NounPhrase{
         determiner: det,
         modifiers: mods,
         head: head,
         post_modifiers: post_mods
       }) do
    ([det | mods] ++ [head | post_mods]) |> Enum.reject(&is_nil/1)
  end

  defp get_children(%VerbPhrase{
         auxiliaries: aux,
         head: head,
         complements: comps,
         adverbials: advs
       }) do
    (aux ++ [head] ++ comps ++ advs) |> Enum.reject(&is_nil/1)
  end

  defp get_children(%PrepositionalPhrase{head: head, object: obj}) do
    [head, obj]
  end

  defp get_children(%AdjectivalPhrase{intensifier: int, head: head, complement: comp}) do
    [int, head, comp] |> Enum.reject(&is_nil/1)
  end

  defp get_children(%AdverbialPhrase{intensifier: int, head: head}) do
    [int, head] |> Enum.reject(&is_nil/1)
  end

  defp get_children(%Token{}), do: []
  defp get_children(_), do: []
end
