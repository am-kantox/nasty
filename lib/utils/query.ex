defmodule Nasty.Utils.Query do
  @moduledoc """
  High-level query API for extracting information from AST.

  Provides convenient functions for common AST queries without
  requiring explicit traversal logic.

  ## Examples

      # Find all noun phrases
      iex> Nasty.Utils.Query.find_all(document, :noun_phrase)
      [%Nasty.AST.NounPhrase{}, ...]

      # Extract entities
      iex> Nasty.Utils.Query.extract_entities(document, type: :PERSON)
      [%Nasty.AST.Entity{text: "John Smith", type: :PERSON}, ...]

      # Find subject of sentence
      iex> Nasty.Utils.Query.find_subject(sentence)
      %Nasty.AST.NounPhrase{head: %Nasty.AST.Token{text: "cat"}}
  """

  alias Nasty.AST.{
    Clause,
    Document,
    Entity,
    NounPhrase,
    Paragraph,
    Sentence,
    Token,
    VerbPhrase
  }

  alias Nasty.Utils.Traversal

  @doc """
  Finds all nodes of a specific type.

  ## Examples

      iex> Nasty.Utils.Query.find_all(document, :noun_phrase)
      [%Nasty.AST.NounPhrase{}, ...]

      iex> Nasty.Utils.Query.find_all(document, :token)
      [%Nasty.AST.Token{}, ...]
  """
  @spec find_all(term(), atom()) :: [term()]
  def find_all(node, type) do
    predicate = fn
      %NounPhrase{} when type == :noun_phrase -> true
      %VerbPhrase{} when type == :verb_phrase -> true
      %Clause{} when type == :clause -> true
      %Sentence{} when type == :sentence -> true
      %Paragraph{} when type == :paragraph -> true
      %Token{} when type == :token -> true
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  @doc """
  Finds all tokens with a specific POS tag.

  ## Examples

      iex> Nasty.Utils.Query.find_by_pos(document, :noun)
      [%Nasty.AST.Token{text: "cat", pos_tag: :noun}, ...]

      iex> Nasty.Utils.Query.find_by_pos(document, :verb)
      [%Nasty.AST.Token{text: "runs", pos_tag: :verb}, ...]
  """
  @spec find_by_pos(term(), atom()) :: [Token.t()]
  def find_by_pos(node, pos_tag) do
    predicate = fn
      %Token{pos_tag: ^pos_tag} -> true
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  @doc """
  Finds all tokens matching a text pattern.

  ## Examples

      iex> Nasty.Utils.Query.find_by_text(document, "cat")
      [%Nasty.AST.Token{text: "cat"}, ...]

      iex> Nasty.Utils.Query.find_by_text(document, ~r/^run/)
      [%Nasty.AST.Token{text: "run"}, %Nasty.AST.Token{text: "runs"}, ...]
  """
  @spec find_by_text(term(), String.t() | Regex.t()) :: [Token.t()]
  def find_by_text(node, pattern) when is_binary(pattern) do
    predicate = fn
      %Token{text: ^pattern} -> true
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  def find_by_text(node, %Regex{} = pattern) do
    predicate = fn
      %Token{text: text} -> Regex.match?(pattern, text)
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  @doc """
  Finds all tokens with a specific lemma.

  ## Examples

      iex> Nasty.Utils.Query.find_by_lemma(document, "run")
      [%Nasty.AST.Token{text: "runs", lemma: "run"}, ...]
  """
  @spec find_by_lemma(term(), String.t()) :: [Token.t()]
  def find_by_lemma(node, lemma) do
    predicate = fn
      %Token{lemma: ^lemma} -> true
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  @doc """
  Extracts all named entities from the document.

  ## Options

  - `:type` - Filter by entity type (e.g., :PERSON, :ORG, :LOC)

  ## Examples

      iex> Nasty.Utils.Query.extract_entities(document)
      [%Nasty.AST.Entity{text: "John", type: :PERSON}, ...]

      iex> Nasty.Utils.Query.extract_entities(document, type: :PERSON)
      [%Nasty.AST.Entity{text: "John", type: :PERSON}, ...]
  """
  @spec extract_entities(term(), keyword()) :: [Entity.t()]
  def extract_entities(node, opts \\ []) do
    entity_type = Keyword.get(opts, :type)

    predicate = fn
      %NounPhrase{entity: %Entity{type: ^entity_type}} when not is_nil(entity_type) -> true
      %NounPhrase{entity: %Entity{}} when is_nil(entity_type) -> true
      _ -> false
    end

    node
    |> Traversal.collect(predicate)
    |> Enum.map(fn %NounPhrase{entity: entity} -> entity end)
    |> Enum.uniq_by(& &1.text)
  end

  @doc """
  Finds the subject of a sentence or clause.

  Returns the subject noun phrase if present, otherwise nil.

  ## Examples

      iex> sentence = %Nasty.AST.Sentence{...}
      iex> Nasty.Utils.Query.find_subject(sentence)
      %Nasty.AST.NounPhrase{head: %Nasty.AST.Token{text: "cat"}}
  """
  @spec find_subject(Sentence.t() | Clause.t()) :: NounPhrase.t() | nil
  def find_subject(%Sentence{main_clause: clause}), do: find_subject(clause)
  def find_subject(%Clause{subject: subject}), do: subject

  @doc """
  Finds the main verb of a sentence or clause.

  Returns the head verb token if present, otherwise nil.

  ## Examples

      iex> sentence = %Nasty.AST.Sentence{...}
      iex> Nasty.Utils.Query.find_main_verb(sentence)
      %Nasty.AST.Token{text: "runs", pos_tag: :verb}
  """
  @spec find_main_verb(Sentence.t() | Clause.t() | VerbPhrase.t()) :: Token.t() | nil
  def find_main_verb(%Sentence{main_clause: clause}), do: find_main_verb(clause)
  def find_main_verb(%Clause{predicate: vp}), do: find_main_verb(vp)
  def find_main_verb(%VerbPhrase{head: head}), do: head

  @doc """
  Finds all objects (complements) of a verb phrase.

  ## Examples

      iex> vp = %Nasty.AST.VerbPhrase{complements: [obj1, obj2]}
      iex> Nasty.Utils.Query.find_objects(vp)
      [obj1, obj2]
  """
  @spec find_objects(VerbPhrase.t() | Clause.t() | Sentence.t()) :: [term()]
  def find_objects(%Sentence{main_clause: clause}), do: find_objects(clause)
  def find_objects(%Clause{predicate: vp}), do: find_objects(vp)
  def find_objects(%VerbPhrase{complements: comps}), do: comps

  @doc """
  Counts nodes of a specific type in the tree.

  ## Examples

      iex> Nasty.Utils.Query.count(document, :token)
      42

      iex> Nasty.Utils.Query.count(document, :sentence)
      7
  """
  @spec count(term(), atom()) :: non_neg_integer()
  def count(node, type) do
    node
    |> find_all(type)
    |> length()
  end

  @doc """
  Checks if any node in the tree matches a predicate.

  ## Examples

      iex> has_verb? = &match?(%Nasty.AST.Token{pos_tag: :verb}, &1)
      iex> Nasty.Utils.Query.any?(document, has_verb?)
      true
  """
  @spec any?(term(), (term() -> boolean())) :: boolean()
  def any?(node, predicate) do
    case Traversal.find(node, predicate) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Checks if all nodes of a type match a predicate.

  ## Examples

      iex> all_lowercase? = fn %Token{text: text} -> text == String.downcase(text) end
      iex> tokens = Nasty.Utils.Query.find_all(document, :token)
      iex> Enum.all?(tokens, all_lowercase?)
      false
  """
  @spec all?(term(), atom(), (term() -> boolean())) :: boolean()
  def all?(node, type, predicate) do
    node
    |> find_all(type)
    |> Enum.all?(predicate)
  end

  @doc """
  Gets all sentences from a document.

  ## Examples

      iex> Nasty.Utils.Query.sentences(document)
      [%Nasty.AST.Sentence{}, ...]
  """
  @spec sentences(Document.t()) :: [Sentence.t()]
  def sentences(%Document{} = doc) do
    Document.all_sentences(doc)
  end

  @doc """
  Gets all tokens from any node.

  ## Examples

      iex> Nasty.Utils.Query.tokens(document)
      [%Nasty.AST.Token{}, ...]
  """
  @spec tokens(term()) :: [Token.t()]
  def tokens(node) do
    find_all(node, :token)
  end

  @doc """
  Gets all content words (nouns, verbs, adjectives, adverbs).

  ## Examples

      iex> Nasty.Utils.Query.content_words(document)
      [%Nasty.AST.Token{text: "cat", pos_tag: :noun}, ...]
  """
  @spec content_words(term()) :: [Token.t()]
  def content_words(node) do
    predicate = fn
      %Token{} = token -> Token.content_word?(token.pos_tag)
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  @doc """
  Gets all function words (determiners, prepositions, conjunctions, etc.).

  ## Examples

      iex> Nasty.Utils.Query.function_words(document)
      [%Nasty.AST.Token{text: "the", pos_tag: :det}, ...]
  """
  @spec function_words(term()) :: [Token.t()]
  def function_words(node) do
    predicate = fn
      %Token{} = token -> Token.function_word?(token.pos_tag)
      _ -> false
    end

    Traversal.collect(node, predicate)
  end

  @doc """
  Filters nodes by a custom predicate function.

  ## Examples

      iex> is_question? = &match?(%Nasty.AST.Sentence{function: :interrogative}, &1)
      iex> Nasty.Utils.Query.filter(document, is_question?)
      [%Nasty.AST.Sentence{function: :interrogative}, ...]
  """
  @spec filter(term(), (term() -> boolean())) :: [term()]
  def filter(node, predicate) do
    Traversal.collect(node, predicate)
  end

  @doc """
  Extracts text spans for all nodes matching a predicate.

  Returns a list of `{text, span}` tuples.

  ## Examples

      iex> is_noun? = &match?(%Nasty.AST.Token{pos_tag: :noun}, &1)
      iex> Nasty.Utils.Query.extract_spans(document, source_text, is_noun?)
      [{"cat", %{start_pos: {1, 4}, end_pos: {1, 7}, ...}}, ...]
  """
  @spec extract_spans(term(), String.t(), (term() -> boolean())) :: [{String.t(), map()}]
  def extract_spans(node, source_text, predicate) do
    node
    |> Traversal.collect(predicate)
    |> Enum.map(fn n ->
      span = get_span(n)

      if span do
        text = Nasty.AST.Node.extract_text(source_text, span)
        {text, span}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Private: Extract span from various node types
  defp get_span(%{span: span}), do: span
  defp get_span(_), do: nil
end
