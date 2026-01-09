defmodule Nasty.AST.Renderer do
  @moduledoc """
  Renders AST nodes back to text.

  Traverses AST structure recursively and extracts text from tokens,
  reconstructing natural language output.

  ## Usage

      alias Nasty.AST.{Document, Renderer}

      # Render complete document
      {:ok, text} = Renderer.render(document)

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

  @doc """
  Renders an AST node to text.

  Returns `{:ok, text}` or `{:error, reason}`.

  ## Examples

      iex> doc = %Document{...}
      iex> Renderer.render(doc)
      {:ok, "The cat sleeps."}

  """
  @spec render(term()) :: {:ok, String.t()} | {:error, term()}
  def render(node)

  # Document
  def render(%Document{paragraphs: paragraphs}) do
    text = Enum.map_join(paragraphs, "\n\n", &render_paragraph/1)
    {:ok, text}
  end

  # Paragraph
  defp render_paragraph(%Paragraph{sentences: sentences}) do
    Enum.map_join(sentences, " ", &render_sentence/1)
  end

  # Sentence
  defp render_sentence(%Sentence{main_clause: main, additional_clauses: additional}) do
    main_text = render_clause(main)

    additional_text =
      additional
      |> Enum.map(&render_clause/1)
      |> Enum.reject(&(&1 == ""))
      |> case do
        [] -> ""
        parts -> " " <> Enum.join(parts, " ")
      end

    main_text <> additional_text <> "."
  end

  # Clause
  defp render_clause(%Clause{subject: subject, predicate: predicate, subordinator: sub}) do
    sub_text = render_optional(sub)
    subject_text = render_optional(subject)
    predicate_text = render_verb_phrase(predicate)

    [sub_text, subject_text, predicate_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  # Noun Phrase
  defp render_noun_phrase(%NounPhrase{
         determiner: det,
         modifiers: mods,
         head: head,
         post_modifiers: post_mods
       }) do
    det_text = render_optional(det)
    mods_text = render_list(mods, " ")
    head_text = render_token(head)
    post_mods_text = render_list(post_mods, " ")

    [det_text, mods_text, head_text, post_mods_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  # Verb Phrase
  defp render_verb_phrase(%VerbPhrase{
         auxiliaries: aux,
         head: head,
         complements: comps,
         adverbials: advs
       }) do
    aux_text = render_list(aux, " ")
    head_text = render_token(head)
    comps_text = render_list(comps, " ")
    advs_text = render_list(advs, " ")

    [aux_text, head_text, comps_text, advs_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  # Prepositional Phrase
  defp render_prepositional_phrase(%PrepositionalPhrase{head: prep, object: obj}) do
    prep_text = render_token(prep)
    obj_text = render_noun_phrase(obj)

    prep_text <> " " <> obj_text
  end

  # Adjectival Phrase
  defp render_adjectival_phrase(%AdjectivalPhrase{
         intensifier: int,
         head: head,
         complement: comp
       }) do
    int_text = render_optional(int)
    head_text = render_token(head)
    comp_text = render_optional(comp)

    [int_text, head_text, comp_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  # Adverbial Phrase
  defp render_adverbial_phrase(%AdverbialPhrase{intensifier: int, head: head}) do
    int_text = render_optional(int)
    head_text = render_token(head)

    [int_text, head_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  # Token
  defp render_token(%Token{text: text}), do: text

  # Generic dispatcher for different node types
  defp render_node(%NounPhrase{} = np), do: render_noun_phrase(np)
  defp render_node(%VerbPhrase{} = vp), do: render_verb_phrase(vp)
  defp render_node(%PrepositionalPhrase{} = pp), do: render_prepositional_phrase(pp)
  defp render_node(%AdjectivalPhrase{} = adjp), do: render_adjectival_phrase(adjp)
  defp render_node(%AdverbialPhrase{} = advp), do: render_adverbial_phrase(advp)
  defp render_node(%Token{} = token), do: render_token(token)
  defp render_node(_), do: ""

  # Render optional node (nil or present)
  defp render_optional(nil), do: ""
  defp render_optional(node), do: render_node(node)

  # Render list of nodes
  defp render_list(nodes, separator) when is_list(nodes) do
    nodes
    |> Enum.map(&render_node/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(separator)
  end
end
