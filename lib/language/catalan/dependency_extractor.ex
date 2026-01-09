defmodule Nasty.Language.Catalan.DependencyExtractor do
  @moduledoc """
  Extracts dependency relations from parsed Catalan syntactic structures.

  Converts phrase structure parses into Universal Dependencies relations.

  ## Catalan-Specific Considerations

  - Subject-verb agreement with pro-drop
  - Clitic pronoun dependencies (em, et, es, el, la)
  - Post-nominal modifier relations
  - Flexible word order (SVO, VSO, VOS)
  """

  alias Nasty.AST.{
    Clause,
    Dependency,
    Node,
    NounPhrase,
    PrepositionalPhrase,
    Sentence,
    Token,
    VerbPhrase
  }

  @spec extract(Sentence.t()) :: [Dependency.t()]
  def extract(%Sentence{main_clause: main_clause, additional_clauses: additional}) do
    main_deps = extract_from_clause(main_clause)
    additional_deps = Enum.flat_map(additional, &extract_from_clause/1)
    main_deps ++ additional_deps
  end

  @spec extract_from_clause(Clause.t()) :: [Dependency.t()]
  def extract_from_clause(%Clause{subject: subject, predicate: predicate} = clause) do
    predicate_head = get_head_token(predicate)

    subject_deps =
      if subject do
        subject_head = get_head_token(subject)

        span =
          Node.make_span(
            subject_head.span.start_pos,
            subject_head.span.start_offset,
            predicate_head.span.end_pos,
            predicate_head.span.end_offset
          )

        [Dependency.new(:nsubj, predicate_head, subject_head, span) | extract_from_np(subject)]
      else
        []
      end

    predicate_deps = extract_from_vp(predicate)

    subordinator_deps =
      if clause.subordinator do
        span =
          Node.make_span(
            clause.subordinator.span.start_pos,
            clause.subordinator.span.start_offset,
            predicate_head.span.end_pos,
            predicate_head.span.end_offset
          )

        [Dependency.new(:mark, predicate_head, clause.subordinator, span)]
      else
        []
      end

    subject_deps ++ predicate_deps ++ subordinator_deps
  end

  defp extract_from_np(%NounPhrase{
         determiner: det,
         modifiers: mods,
         head: head,
         post_modifiers: post_mods
       }) do
    deps = []

    deps =
      if det do
        span =
          Node.make_span(
            det.span.start_pos,
            det.span.start_offset,
            head.span.end_pos,
            head.span.end_offset
          )

        [Dependency.new(:det, head, det, span) | deps]
      else
        deps
      end

    mod_deps =
      Enum.map(mods, fn mod ->
        span =
          Node.make_span(
            mod.span.start_pos,
            mod.span.start_offset,
            head.span.end_pos,
            head.span.end_offset
          )

        Dependency.new(:amod, head, mod, span)
      end)

    post_deps =
      Enum.flat_map(post_mods, fn
        %PrepositionalPhrase{} = pp -> extract_from_pp(pp, head)
        _ -> []
      end)

    deps ++ mod_deps ++ post_deps
  end

  defp extract_from_vp(%VerbPhrase{auxiliaries: aux, head: head, complements: comps}) do
    aux_deps =
      Enum.map(aux, fn aux_token ->
        span =
          Node.make_span(
            aux_token.span.start_pos,
            aux_token.span.start_offset,
            head.span.end_pos,
            head.span.end_offset
          )

        Dependency.new(:aux, head, aux_token, span)
      end)

    comp_deps =
      Enum.flat_map(comps, fn
        %NounPhrase{} = np ->
          np_head = get_head_token(np)

          span =
            Node.make_span(
              head.span.start_pos,
              head.span.start_offset,
              np_head.span.end_pos,
              np_head.span.end_offset
            )

          [Dependency.new(:obj, head, np_head, span) | extract_from_np(np)]

        %PrepositionalPhrase{} = pp ->
          extract_from_pp_as_complement(pp, head)

        %Token{pos_tag: :adv} = adv_token ->
          span =
            Node.make_span(
              head.span.start_pos,
              head.span.start_offset,
              adv_token.span.end_pos,
              adv_token.span.end_offset
            )

          [Dependency.new(:advmod, head, adv_token, span)]

        _ ->
          []
      end)

    aux_deps ++ comp_deps
  end

  defp extract_from_pp(%PrepositionalPhrase{head: prep, object: obj}, head) do
    obj_head = get_head_token(obj)

    nmod_span =
      Node.make_span(
        head.span.start_pos,
        head.span.start_offset,
        obj_head.span.end_pos,
        obj_head.span.end_offset
      )

    case_span =
      Node.make_span(
        prep.span.start_pos,
        prep.span.start_offset,
        obj_head.span.end_pos,
        obj_head.span.end_offset
      )

    [
      Dependency.new(:nmod, head, obj_head, nmod_span),
      Dependency.new(:case, obj_head, prep, case_span)
      | extract_from_np(obj)
    ]
  end

  defp extract_from_pp_as_complement(%PrepositionalPhrase{head: prep, object: obj}, head) do
    obj_head = get_head_token(obj)

    obl_span =
      Node.make_span(
        head.span.start_pos,
        head.span.start_offset,
        obj_head.span.end_pos,
        obj_head.span.end_offset
      )

    case_span =
      Node.make_span(
        prep.span.start_pos,
        prep.span.start_offset,
        obj_head.span.end_pos,
        obj_head.span.end_offset
      )

    [
      Dependency.new(:obl, head, obj_head, obl_span),
      Dependency.new(:case, obj_head, prep, case_span)
      | extract_from_np(obj)
    ]
  end

  defp get_head_token(%NounPhrase{head: head}), do: head
  defp get_head_token(%VerbPhrase{head: head}), do: head
  defp get_head_token(%PrepositionalPhrase{object: obj}), do: get_head_token(obj)
  defp get_head_token(%Token{} = token), do: token
  defp get_head_token(_), do: nil
end
