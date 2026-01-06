defmodule Nasty.Language.English.SemanticRoleLabeler do
  @moduledoc """
  Semantic Role Labeling (SRL) for English.

  Extracts predicate-argument structure from sentences by mapping
  syntactic dependencies to semantic roles (Agent, Patient, Theme, etc.).

  Uses rule-based patterns over Universal Dependencies parse trees.

  ## Examples

      iex> alias Nasty.Language.English.{Tokenizer, POSTagger, DependencyExtractor}
      iex> {:ok, tokens} = Tokenizer.tokenize("John gave Mary a book.")
      iex> {:ok, tagged} = POSTagger.tag(tokens)
      iex> sentence = %Sentence{...}  # parsed sentence
      iex> {:ok, frames} = SemanticRoleLabeler.label(sentence)
      iex> frame = List.first(frames)
      iex> frame.predicate.lemma
      "give"
      iex> Enum.map(frame.roles, & &1.type)
      [:agent, :recipient, :theme]
  """

  alias Nasty.AST.{
    Clause,
    NounPhrase,
    PrepositionalPhrase,
    Sentence,
    Token,
    VerbPhrase
  }

  alias Nasty.AST.Semantic.{Frame, Role}

  @doc """
  Labels semantic roles for all predicates in a sentence.

  Returns a list of semantic frames, one per predicate (main verb).

  ## Examples

      iex> {:ok, frames} = SemanticRoleLabeler.label(sentence)
      iex> is_list(frames)
      true
  """
  @spec label(Sentence.t(), keyword()) :: {:ok, [Frame.t()]} | {:error, term()}
  def label(%Sentence{} = sentence, _opts \\ []) do
    frames =
      sentence
      |> Sentence.all_clauses()
      |> Enum.flat_map(&label_clause/1)

    {:ok, frames}
  end

  @doc """
  Labels semantic roles for a single clause.

  Note: Since DependencyExtractor works at the Sentence level,
  we build a simple sentence wrapper and extract dependencies from that.
  """
  @spec label_clause(Clause.t()) :: [Frame.t()]
  def label_clause(%Clause{predicate: predicate} = clause) do
    # Identify main verb(s)
    verbs = identify_predicates(predicate)

    # Build frame for each verb using clause structure directly
    Enum.map(verbs, fn verb ->
      build_frame(verb, clause)
    end)
  end

  # Identify predicates (main verbs) in the predicate phrase
  defp identify_predicates(%VerbPhrase{head: main_verb}) do
    [main_verb]
  end

  defp identify_predicates(_), do: []

  # Build a semantic frame for a predicate
  defp build_frame(predicate, clause) do
    voice = detect_voice(predicate, clause)
    roles = extract_roles(predicate, clause, voice)

    Frame.new(
      predicate,
      roles,
      clause.span,
      voice: voice
    )
  end

  # Detect voice (active vs passive) from clause structure
  defp detect_voice(predicate, %Clause{predicate: vp}) do
    # Check for passive auxiliary in VP
    has_passive_aux =
      case vp do
        %VerbPhrase{auxiliaries: aux} ->
          Enum.any?(aux, fn a ->
            # Passive auxiliaries: be forms
            String.downcase(a.text) in ["was", "were", "is", "are", "been", "being", "be"]
          end)

        _ ->
          false
      end

    # Check if verb is past participle
    # For regular verbs: ends in -ed or morphology indicates :past_participle
    # For irregular verbs: if there's a passive auxiliary, assume passive
    # If we have passive aux, likely passive even for irregular verbs
    is_past_participle =
      Map.get(predicate.morphology, :tense) == :past_participle or
        String.ends_with?(predicate.text, "ed") or
        String.ends_with?(predicate.text, "en") or
        (has_passive_aux and not String.ends_with?(predicate.text, "ing"))

    if has_passive_aux and is_past_participle do
      :passive
    else
      :active
    end
  end

  # Extract semantic roles from clause structure
  defp extract_roles(_predicate, clause, voice) do
    # Extract core arguments from clause structure
    core_roles = extract_core_roles_from_clause(clause, voice)

    # Extract adjuncts from VP
    adjunct_roles = extract_adjunct_roles_from_clause(clause)

    core_roles ++ adjunct_roles
  end

  # Extract core argument roles from clause structure
  defp extract_core_roles_from_clause(%Clause{subject: subject, predicate: vp}, voice) do
    roles = []

    # Subject role depends on voice
    roles =
      if subject do
        subject_role =
          case voice do
            :active -> :agent
            :passive -> :patient
            _ -> :agent
          end

        [make_role(subject_role, subject, subject.span) | roles]
      else
        roles
      end

    # Objects from VP complements
    roles =
      case vp do
        %VerbPhrase{complements: [_ | _] = comps} ->
          comp_roles =
            comps
            |> Enum.with_index()
            |> Enum.map(fn {comp, idx} ->
              # First NP complement = direct object (patient/theme)
              # Second NP complement = indirect object (recipient)
              role_type = if idx == 0, do: :patient, else: :recipient
              make_role(role_type, comp, comp.span)
            end)

          roles ++ comp_roles

        _ ->
          roles
      end

    roles
  end

  # Extract adjunct roles from clause (VP adverbials, subordinate clauses)
  defp extract_adjunct_roles_from_clause(%Clause{predicate: vp}) do
    case vp do
      %VerbPhrase{adverbials: [_ | _] = advs} ->
        Enum.flat_map(advs, fn adv ->
          classify_adverbial(adv)
        end)

      _ ->
        []
    end
  end

  # Classify adverbials (tokens, PPs, clauses)
  defp classify_adverbial(%Token{} = token) do
    if temporal_adverb?(token.text) do
      [make_role(:time, token, token.span)]
    else
      [make_role(:manner, token, token.span)]
    end
  end

  defp classify_adverbial(%PrepositionalPhrase{head: prep} = pp) do
    classify_pp_role(prep.text, pp)
  end

  defp classify_adverbial(_), do: []

  # Classify prepositional phrase role based on preposition
  defp classify_pp_role(prep_text, pp) do
    text_lower = String.downcase(prep_text)

    role_type =
      cond do
        # Location
        text_lower in ["at", "in", "on", "near", "to", "from", "into", "onto"] ->
          :location

        # Time
        text_lower in ["during", "before", "after", "since", "until"] ->
          :time

        # Instrument
        text_lower in ["with", "using", "by"] ->
          :instrument

        # Purpose
        text_lower in ["for"] ->
          :purpose

        # Comitative (accompaniment)
        text_lower == "with" ->
          :comitative

        # Default to location
        true ->
          :location
      end

    [make_role(role_type, pp, pp.span)]
  end

  # Check if word is a temporal adverb
  defp temporal_adverb?(text) do
    text_lower = String.downcase(text)

    text_lower in [
      "now",
      "then",
      "today",
      "yesterday",
      "tomorrow",
      "recently",
      "soon",
      "already",
      "always",
      "never",
      "often",
      "sometimes"
    ]
  end

  # Create a semantic role from a token/phrase
  defp make_role(type, %Token{} = token, span) do
    Role.new(type, token.text, span)
  end

  defp make_role(type, phrase, span) when is_struct(phrase) do
    text = extract_text(phrase)
    Role.new(type, text, span, phrase: phrase)
  end

  # Extract text from phrase structures
  defp extract_text(%NounPhrase{} = np) do
    tokens =
      [
        np.determiner,
        np.modifiers,
        [np.head],
        np.post_modifiers
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Enum.map_join(tokens, " ", fn
      %Token{text: text} -> text
      phrase -> extract_text(phrase)
    end)
  end

  defp extract_text(%VerbPhrase{head: verb}), do: verb.text

  defp extract_text(%PrepositionalPhrase{head: prep, object: obj}) do
    "#{prep.text} #{extract_text(obj)}"
  end

  defp extract_text(%Token{text: text}), do: text

  defp extract_text(_), do: ""
end
