defmodule Nasty.Language.Spanish.SRLConfig do
  @moduledoc """
  Configuration for Spanish Semantic Role Labeling (SRL).

  Provides Spanish-specific verb frames, argument patterns, and role
  identification rules for the generic SRL labeler.

  ## Spanish Verb Frames

  Spanish verbs follow similar argument structures to English:
  - Agent (A0): quien realiza la acción (who performs action)
  - Patient (A1): quien recibe la acción (who receives action)
  - Instrument (A2): con qué se realiza (with what)
  - Beneficiary (A3): para quién (for whom)
  - Location: dónde (where)
  - Time: cuándo (when)

  ## Spanish-Specific Features

  - Flexible word order (SVO, VSO, VOS)
  - Pro-drop subjects (null agent)
  - Reflexive constructions (se constructions)
  - Clitic pronouns encoding arguments

  ## Example

      iex> sentence = parse("María le dio un libro a Juan ayer")
      iex> roles = SRLLabeler.label(sentence)
      [
        %Role{type: :agent, span: "María"},
        %Role{type: :theme, span: "un libro"},
        %Role{type: :recipient, span: "a Juan"},
        %Role{type: :time, span: "ayer"}
      ]
  """

  @doc """
  Returns Spanish SRL configuration for use by the generic labeler.
  """
  @spec get() :: map()
  def get do
    %{
      # Verb frames mapping verb classes to expected argument structures
      verb_frames: %{
        # Transitive verbs (agent + patient)
        transitive: [
          "comer",
          "ver",
          "leer",
          "escribir",
          "comprar",
          "vender",
          "hacer",
          "tomar",
          "poner",
          "llevar"
        ],
        # Ditransitive verbs (agent + theme + recipient)
        ditransitive: [
          "dar",
          "enviar",
          "mostrar",
          "enseñar",
          "decir",
          "contar",
          "prestar",
          "ofrecer",
          "regalar"
        ],
        # Intransitive verbs (agent only)
        intransitive: [
          "correr",
          "saltar",
          "nadar",
          "dormir",
          "caminar",
          "venir",
          "ir",
          "llegar",
          "salir"
        ],
        # Perception verbs
        perception: ["ver", "oír", "escuchar", "mirar", "sentir", "observar"],
        # Communication verbs
        communication: ["decir", "hablar", "contar", "preguntar", "responder", "gritar"],
        # Motion verbs
        motion: ["ir", "venir", "llegar", "salir", "entrar", "subir", "bajar", "volver"],
        # Transfer verbs
        transfer: ["dar", "enviar", "mandar", "entregar", "pasar", "llevar"]
      },
      # Prepositions that mark semantic roles
      role_markers: %{
        # Agent markers (rare, mostly in passives)
        agent: ["por"],
        # Patient/theme markers
        patient: ["a"],
        # Location markers
        location: ["en", "a", "de", "desde", "hasta", "por", "sobre", "bajo", "entre"],
        # Time markers
        time: ["en", "a", "de", "desde", "hasta", "por", "durante"],
        # Instrument markers
        instrument: ["con", "mediante", "por"],
        # Beneficiary markers
        beneficiary: ["para", "por"],
        # Source markers
        source: ["de", "desde"],
        # Goal markers
        goal: ["a", "hacia", "para"],
        # Manner markers
        manner: ["con", "de"],
        # Purpose markers
        purpose: ["para", "por"]
      },
      # Clitic pronouns encoding arguments
      clitics: %{
        # Direct object clitics (theme/patient)
        accusative: ["me", "te", "lo", "la", "nos", "os", "los", "las"],
        # Indirect object clitics (recipient/beneficiary)
        dative: ["me", "te", "le", "nos", "os", "les"],
        # Reflexive (agent = patient)
        reflexive: ["se"]
      },
      # Argument identification rules
      rules: %{
        # Subject is typically agent (except in passives)
        subject_is_agent: true,
        # Direct object is typically patient/theme
        object_is_patient: true,
        # Indirect object is typically recipient/beneficiary
        indirect_object_is_recipient: true,
        # Handle pro-drop (null subjects)
        allow_null_agent: true,
        # Handle reflexive constructions
        handle_reflexives: true,
        # Prefer animate agents
        animate_agent_preference: 0.8
      }
    }
  end

  @doc """
  Returns the verb frame for a given Spanish verb (lemma).
  """
  @spec get_verb_frame(String.t()) :: atom() | nil
  def get_verb_frame(verb_lemma) do
    config = get()
    normalized = String.downcase(verb_lemma)

    Enum.find_value(config.verb_frames, fn {frame, verbs} ->
      if normalized in verbs, do: frame
    end)
  end

  @doc """
  Returns the semantic role typically associated with a Spanish preposition.
  """
  @spec get_role_for_preposition(String.t()) :: atom() | nil
  def get_role_for_preposition(prep) do
    config = get()
    normalized = String.downcase(prep)

    Enum.find_value(config.role_markers, fn {role, preps} ->
      if normalized in preps, do: role
    end)
  end

  @doc """
  Returns true if the clitic is a direct object (accusative).
  """
  @spec accusative_clitic?(String.t()) :: boolean()
  def accusative_clitic?(clitic) do
    config = get()
    normalized = String.downcase(clitic)
    normalized in config.clitics.accusative
  end

  @doc """
  Returns true if the clitic is an indirect object (dative).
  """
  @spec dative_clitic?(String.t()) :: boolean()
  def dative_clitic?(clitic) do
    config = get()
    normalized = String.downcase(clitic)
    normalized in config.clitics.dative
  end

  @doc """
  Returns true if the clitic is reflexive.
  """
  @spec reflexive_clitic?(String.t()) :: boolean()
  def reflexive_clitic?(clitic) do
    config = get()
    normalized = String.downcase(clitic)
    normalized in config.clitics.reflexive
  end
end
