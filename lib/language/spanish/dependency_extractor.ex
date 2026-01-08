defmodule Nasty.Language.Spanish.DependencyExtractor do
  @moduledoc """
  Extracts dependency relations from parsed Spanish syntactic structures.

  Converts phrase structure parses (NP, VP, PP, etc.) into Universal Dependencies
  relations, creating a dependency graph that captures grammatical relationships.

  ## Spanish-Specific Considerations

  - Subject-verb agreement with pro-drop
  - Clitic pronoun dependencies
  - Post-nominal modifier relations
  - Flexible word order (SVO, VSO, VOS)

  ## Example

      iex> sentence = parse("El gato se sentó en la alfombra")
      iex> deps = DependencyExtractor.extract(sentence)
      [
        %Dependency{relation: :det, head: gato, dependent: el},
        %Dependency{relation: :nsubj, head: sentó, dependent: gato},
        %Dependency{relation: :expl:pv, head: sentó, dependent: se},
        %Dependency{relation: :case, head: alfombra, dependent: en},
        %Dependency{relation: :det, head: alfombra, dependent: la},
        %Dependency{relation: :obl, head: sentó, dependent: alfombra}
      ]
  """

  alias Nasty.AST.{
    AdjectivalPhrase,
    AdverbialPhrase,
    Clause,
    Dependency,
    Node,
    NounPhrase,
    PrepositionalPhrase,
    RelativeClause,
    Sentence,
    Token,
    VerbPhrase
  }

  @doc """
  Extracts all dependencies from a Spanish sentence.

  Returns a list of Dependency structs representing grammatical relations.
  """
  @spec extract(Sentence.t()) :: [Dependency.t()]
  def extract(%Sentence{main_clause: main_clause, additional_clauses: additional}) do
    # Extract from main clause
    main_deps = extract_from_clause(main_clause)

    # Extract from additional clauses (coordination)
    additional_deps =
      additional
      |> Enum.flat_map(&extract_from_clause/1)

    main_deps ++ additional_deps
  end

  @doc """
  Extracts dependencies from a single Spanish clause.
  """
  @spec extract_from_clause(Clause.t()) :: [Dependency.t()]
  def extract_from_clause(%Clause{subject: subject, predicate: predicate} = clause) do
    predicate_head = get_head_token(predicate)

    # Subject → Predicate relation
    # Spanish allows null subjects (pro-drop), so subject may be nil
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

        subject_dep = Dependency.new(:nsubj, predicate_head, subject_head, span)
        [subject_dep | extract_from_np(subject)]
      else
        []
      end

    # Predicate and its dependents
    predicate_deps = extract_from_vp(predicate)

    # Subordinator (if any)
    # Spanish: que, porque, cuando, si, aunque, mientras, etc.
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

  # Extract dependencies from a noun phrase
  # Spanish: determiner + (quantifiers) + noun + (adjectives) + (PPs/RCs)
  defp extract_from_np(%NounPhrase{
         determiner: det,
         modifiers: mods,
         head: head,
         post_modifiers: post_mods
       }) do
    deps = []

    # Determiner → Head
    # Spanish articles: el, la, los, las, un, una, unos, unas
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

    # Modifiers (adjectives and quantifiers) → Head
    # Spanish: both pre-nominal (quantifiers) and post-nominal (adjectives)
    mod_deps =
      mods
      |> Enum.map(fn mod ->
        span =
          Node.make_span(
            mod.span.start_pos,
            mod.span.start_offset,
            head.span.end_pos,
            head.span.end_offset
          )

        Dependency.new(:amod, head, mod, span)
      end)

    # Post-modifiers (PPs, RCs)
    post_deps =
      post_mods
      |> Enum.flat_map(fn
        %PrepositionalPhrase{} = pp -> extract_from_pp(pp, head)
        %RelativeClause{} = rc -> extract_from_rc(rc, head)
        _ -> []
      end)

    deps ++ mod_deps ++ post_deps
  end

  # Extract dependencies from a verb phrase
  # Spanish: (auxiliaries) + verb + (clitics) + (complements)
  defp extract_from_vp(%VerbPhrase{auxiliaries: aux, head: head, complements: comps}) do
    deps = []

    # Auxiliaries → Head
    # Spanish: haber, ser, estar
    aux_deps =
      aux
      |> Enum.map(fn aux_token ->
        span =
          Node.make_span(
            aux_token.span.start_pos,
            aux_token.span.start_offset,
            head.span.end_pos,
            head.span.end_offset
          )

        Dependency.new(:aux, head, aux_token, span)
      end)

    # Complements (objects, PPs, adverbs)
    comp_deps =
      comps
      |> Enum.flat_map(fn
        %NounPhrase{} = np ->
          # Direct object
          np_head = get_head_token(np)

          span =
            Node.make_span(
              head.span.start_pos,
              head.span.start_offset,
              np_head.span.end_pos,
              np_head.span.end_offset
            )

          obj_dep = Dependency.new(:obj, head, np_head, span)
          [obj_dep | extract_from_np(np)]

        %PrepositionalPhrase{} = pp ->
          extract_from_pp(pp, head)

        %AdverbialPhrase{head: adv} ->
          span =
            Node.make_span(
              head.span.start_pos,
              head.span.start_offset,
              adv.span.end_pos,
              adv.span.end_offset
            )

          [Dependency.new(:advmod, head, adv, span)]

        _ ->
          []
      end)

    deps ++ aux_deps ++ comp_deps
  end

  # Extract dependencies from a prepositional phrase
  # Spanish prepositions: a, de, en, con, por, para, sin, sobre, etc.
  defp extract_from_pp(%PrepositionalPhrase{head: prep, object: obj}, governor) do
    obj_head = get_head_token(obj)

    # Prep → Object (case marking)
    prep_span =
      Node.make_span(
        prep.span.start_pos,
        prep.span.start_offset,
        obj_head.span.end_pos,
        obj_head.span.end_offset
      )

    case_dep = Dependency.new(:case, obj_head, prep, prep_span)

    # Governor → Object (oblique or nominal modifier)
    gov_span =
      Node.make_span(
        governor.span.start_pos,
        governor.span.start_offset,
        obj_head.span.end_pos,
        obj_head.span.end_offset
      )

    # Use :obl for verb governors, :nmod for noun governors
    relation = if governor.pos_tag == :verb, do: :obl, else: :nmod
    obl_dep = Dependency.new(relation, governor, obj_head, gov_span)

    # Dependencies within the object NP
    obj_deps = extract_from_np(obj)

    [case_dep, obl_dep | obj_deps]
  end

  # Extract dependencies from a relative clause
  # Spanish relativizers: que, quien, quienes, cual, cuales, donde, cuando, como
  defp extract_from_rc(
         %RelativeClause{relativizer: rel, clause: clause},
         head_noun
       ) do
    clause_head = get_head_token(clause.predicate)

    # Head noun → Clause head (acl = clausal modifier of noun)
    span =
      Node.make_span(
        head_noun.span.start_pos,
        head_noun.span.start_offset,
        clause_head.span.end_pos,
        clause_head.span.end_offset
      )

    acl_dep = Dependency.new(:acl, head_noun, clause_head, span)

    # Relativizer → Clause head (mark)
    rel_span =
      Node.make_span(
        rel.span.start_pos,
        rel.span.start_offset,
        clause_head.span.end_pos,
        clause_head.span.end_offset
      )

    mark_dep = Dependency.new(:mark, clause_head, rel, rel_span)

    # Dependencies within the relative clause
    clause_deps = extract_from_clause(clause)

    [acl_dep, mark_dep | clause_deps]
  end

  # Get the head token from a phrase structure
  defp get_head_token(%NounPhrase{head: head}), do: head
  defp get_head_token(%VerbPhrase{head: head}), do: head
  defp get_head_token(%PrepositionalPhrase{head: head}), do: head
  defp get_head_token(%AdjectivalPhrase{head: head}), do: head
  defp get_head_token(%AdverbialPhrase{head: head}), do: head
  defp get_head_token(%Clause{predicate: vp}), do: get_head_token(vp)
  defp get_head_token(%Token{} = token), do: token
end
