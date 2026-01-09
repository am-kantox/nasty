defmodule Nasty.Translation.Agreement do
  @moduledoc """
  Enforces grammatical agreement in target language.

  Different languages require agreement between words:
  - Gender agreement: adjectives, articles, determiners agree with nouns (Spanish, Catalan)
  - Number agreement: verbs agree with subjects, adjectives with nouns
  - Person agreement: verb conjugation matches subject person

  English has minimal agreement (only number and person for verbs),
  while Romance languages have extensive agreement.

  ## Usage

      alias Nasty.AST.{NounPhrase, Token}
      alias Nasty.Translation.Agreement

      # Enforce agreement in noun phrase
      np = %NounPhrase{
        determiner: %Token{text: "el"},
        modifiers: [],
        head: %Token{text: "gata", morphology: %{gender: :f}}
      }
      
      corrected = Agreement.enforce_noun_phrase_agreement(np, :es)
      # => %NounPhrase{determiner: %Token{text: "la"}, ...}

  """

  alias Nasty.AST.{Clause, NounPhrase, Token, VerbPhrase}

  @doc """
  Enforces agreement in a noun phrase based on the head noun's features.

  Modifies determiners, modifiers (adjectives), and post-modifiers to agree
  with the head noun in gender and number.

  ## Examples

      iex> np = %NounPhrase{head: %Token{morphology: %{gender: :f, number: :sg}}, ...}
      iex> Agreement.enforce_noun_phrase_agreement(np, :es)
      # Adjusts all modifiers to feminine singular

  """
  @spec enforce_noun_phrase_agreement(NounPhrase.t(), atom()) :: NounPhrase.t()
  def enforce_noun_phrase_agreement(%NounPhrase{head: head} = np, lang) when lang in [:es, :ca] do
    # Extract gender and number from head noun
    gender = get_gender(head)
    number = get_number(head)

    # Apply agreement to all phrase components
    %{
      np
      | determiner: apply_agreement_to_token(np.determiner, gender, number, lang),
        modifiers: Enum.map(np.modifiers, &apply_agreement(&1, gender, number, lang)),
        post_modifiers: Enum.map(np.post_modifiers, &apply_agreement(&1, gender, number, lang))
    }
  end

  # English doesn't have gender/number agreement for adjectives
  def enforce_noun_phrase_agreement(%NounPhrase{} = np, :en), do: np

  @doc """
  Enforces subject-verb agreement in a clause.

  Ensures the verb agrees with its subject in person and number.

  ## Examples

      iex> clause = %Clause{subject: np, predicate: vp, ...}
      iex> Agreement.enforce_subject_verb_agreement(clause, :es)
      # Conjugates verb to match subject person/number

  """
  @spec enforce_subject_verb_agreement(Clause.t(), atom()) :: Clause.t()
  def enforce_subject_verb_agreement(
        %Clause{subject: subject, predicate: predicate} = clause,
        lang
      )
      when not is_nil(subject) do
    # Extract person and number from subject
    person = get_person(subject)
    number = get_subject_number(subject)

    # Apply agreement to verb phrase
    updated_predicate = enforce_verb_agreement(predicate, person, number, lang)

    %{clause | predicate: updated_predicate}
  end

  def enforce_subject_verb_agreement(%Clause{} = clause, _lang), do: clause

  ## Private Functions - Feature Extraction

  # Get gender from token or default to masculine
  defp get_gender(%Token{morphology: %{gender: gender}}) when not is_nil(gender), do: gender
  defp get_gender(_), do: :m

  # Get number from token or default to singular
  defp get_number(%Token{morphology: %{number: number}}) when not is_nil(number), do: number
  defp get_number(_), do: :sg

  # Get person from noun phrase (defaults to 3rd person)
  defp get_person(%NounPhrase{}), do: 3
  defp get_person(_), do: 3

  # Get number from subject (noun phrase)
  defp get_subject_number(%NounPhrase{head: head}), do: get_number(head)
  defp get_subject_number(_), do: :sg

  ## Private Functions - Agreement Application

  # Apply agreement to mixed node types
  defp apply_agreement(%Token{} = token, gender, number, lang) do
    apply_agreement_to_token(token, gender, number, lang)
  end

  defp apply_agreement(node, _gender, _number, _lang), do: node

  # Apply gender/number agreement to a token
  defp apply_agreement_to_token(nil, _gender, _number, _lang), do: nil

  defp apply_agreement_to_token(%Token{pos_tag: :DET} = token, gender, number, lang) do
    # Adjust determiner (el/la, los/las, un/una, etc.)
    new_text = adjust_determiner(token.text, gender, number, lang)

    %{
      token
      | text: new_text,
        morphology: Map.merge(token.morphology || %{}, %{gender: gender, number: number})
    }
  end

  defp apply_agreement_to_token(%Token{pos_tag: :ADJ} = token, gender, number, lang) do
    # Adjust adjective ending
    new_text = adjust_adjective(token.text, token.lemma, gender, number, lang)

    %{
      token
      | text: new_text,
        morphology: Map.merge(token.morphology || %{}, %{gender: gender, number: number})
    }
  end

  defp apply_agreement_to_token(token, _gender, _number, _lang), do: token

  # Adjust determiner text based on gender/number
  defp adjust_determiner(text, gender, number, lang) when lang in [:es, :ca] do
    base = String.downcase(text)

    case {base, gender, number, lang} do
      # Spanish definite articles
      {det, :m, :sg, :es} when det in ["el", "la", "los", "las"] -> "el"
      {det, :f, :sg, :es} when det in ["el", "la", "los", "las"] -> "la"
      {det, :m, :pl, :es} when det in ["el", "la", "los", "las"] -> "los"
      {det, :f, :pl, :es} when det in ["el", "la", "los", "las"] -> "las"
      # Spanish indefinite articles
      {det, :m, :sg, :es} when det in ["un", "una", "unos", "unas"] -> "un"
      {det, :f, :sg, :es} when det in ["un", "una", "unos", "unas"] -> "una"
      {det, :m, :pl, :es} when det in ["un", "una", "unos", "unas"] -> "unos"
      {det, :f, :pl, :es} when det in ["un", "una", "unos", "unas"] -> "unas"
      # Catalan definite articles
      {det, :m, :sg, :ca} when det in ["el", "la", "els", "les", "l'"] -> "el"
      {det, :f, :sg, :ca} when det in ["el", "la", "els", "les", "l'"] -> "la"
      {det, :m, :pl, :ca} when det in ["el", "la", "els", "les"] -> "els"
      {det, :f, :pl, :ca} when det in ["el", "la", "els", "les"] -> "les"
      # Catalan indefinite articles
      {det, :m, :sg, :ca} when det in ["un", "una", "uns", "unes"] -> "un"
      {det, :f, :sg, :ca} when det in ["un", "una", "uns", "unes"] -> "una"
      {det, :m, :pl, :ca} when det in ["un", "una", "uns", "unes"] -> "uns"
      {det, :f, :pl, :ca} when det in ["un", "una", "uns", "unes"] -> "unes"
      # Default: keep original
      _ -> text
    end
  end

  defp adjust_determiner(text, _gender, _number, _lang), do: text

  # Adjust adjective ending based on gender/number
  defp adjust_adjective(text, lemma, gender, number, lang) when lang in [:es, :ca] do
    base_form = lemma || text

    # Handle invariant adjectives (ending in -e, consonants like -l, -r, -z)
    if invariant_adjective?(base_form) do
      # Only adjust for number, not gender
      adjust_for_number(base_form, number, lang)
    else
      # Regular adjectives: adjust both gender and number
      case {gender, number} do
        {:m, :sg} -> make_masculine_singular(base_form)
        {:f, :sg} -> make_feminine_singular(base_form)
        {:m, :pl} -> make_masculine_plural(base_form)
        {:f, :pl} -> make_feminine_plural(base_form)
      end
    end
  end

  defp adjust_adjective(text, _lemma, _gender, _number, _lang), do: text

  # Check if adjective is invariant for gender
  defp invariant_adjective?(text) do
    String.ends_with?(text, ["e", "l", "r", "z", "ista"])
  end

  # Adjust only for number (plural)
  defp adjust_for_number(text, :pl, _lang) do
    cond do
      String.ends_with?(text, "z") -> String.replace_suffix(text, "z", "ces")
      String.ends_with?(text, ["a", "e", "o"]) -> text <> "s"
      true -> text <> "es"
    end
  end

  defp adjust_for_number(text, :sg, _lang), do: text

  # Make adjective masculine singular
  defp make_masculine_singular(text) do
    if String.ends_with?(text, "a") do
      String.replace_suffix(text, "a", "o")
    else
      text
    end
  end

  # Make adjective feminine singular
  defp make_feminine_singular(text) do
    if String.ends_with?(text, "o") do
      String.replace_suffix(text, "o", "a")
    else
      text
    end
  end

  # Make adjective masculine plural
  defp make_masculine_plural(text) do
    base = make_masculine_singular(text)
    adjust_for_number(base, :pl, :es)
  end

  # Make adjective feminine plural
  defp make_feminine_plural(text) do
    base = make_feminine_singular(text)
    adjust_for_number(base, :pl, :es)
  end

  ## Private Functions - Verb Agreement

  # Enforce verb person/number agreement
  defp enforce_verb_agreement(%VerbPhrase{head: verb} = vp, person, number, lang)
       when lang in [:es, :ca] do
    # Conjugate verb to match subject
    conjugated_verb = conjugate_verb(verb, person, number, lang)
    %{vp | head: conjugated_verb}
  end

  defp enforce_verb_agreement(vp, _person, _number, _lang), do: vp

  # Conjugate verb based on person and number
  defp conjugate_verb(%Token{} = verb, person, number, _lang) do
    # This is a simplified version - full conjugation requires verb class info
    # For now, just update morphology
    new_morphology =
      Map.merge(verb.morphology || %{}, %{person: person, number: number})

    %{verb | morphology: new_morphology}
    # [TODO]: Actually modify verb.text based on conjugation rules
    # This would require accessing verb class (-ar, -er, -ir) and tense
  end
end
