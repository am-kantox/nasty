defmodule Nasty.Semantic.SRL.CoreArgumentMapper do
  @moduledoc """
  Generic mapping from syntactic arguments to semantic roles.

  Maps clause components (subject, objects, complements) to semantic roles
  based on voice and argument position:

  ## Active Voice
  - Subject → Agent
  - Object 1 → Patient/Theme
  - Object 2 → Recipient

  ## Passive Voice
  - Subject → Patient
  - By-phrase → Agent (if present)
  """

  alias Nasty.AST.{Clause, NounPhrase, PrepositionalPhrase, Token, VerbPhrase}
  alias Nasty.AST.Semantic.Role

  @doc """
  Extracts core semantic roles from a clause based on voice.

  Core roles are essential arguments of the predicate (agent, patient, theme, recipient, etc.)
  """
  @spec extract_core_roles(Clause.t(), :active | :passive | :unknown) :: [Role.t()]
  def extract_core_roles(%Clause{subject: subject, predicate: vp}, voice) do
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

    # Extract complement roles from VP
    roles = roles ++ extract_complement_roles(vp)

    roles
  end

  # Extract roles from VP complements (direct/indirect objects)
  defp extract_complement_roles(%VerbPhrase{complements: [_ | _] = complements}) do
    complements
    |> Enum.with_index()
    |> Enum.map(fn {comp, idx} ->
      # First NP complement = direct object (patient/theme)
      # Second NP complement = indirect object (recipient)
      role_type = if idx == 0, do: :patient, else: :recipient
      make_role(role_type, comp, comp.span)
    end)
  end

  defp extract_complement_roles(_), do: []

  # Create a semantic role from a syntactic element
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
