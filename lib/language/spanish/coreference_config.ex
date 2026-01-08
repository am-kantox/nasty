defmodule Nasty.Language.Spanish.CoreferenceConfig do
  @moduledoc """
  Configuration for Spanish coreference resolution.

  Provides Spanish-specific pronoun lists, gender/number patterns, and
  resolution rules for the generic coreference resolver.

  ## Spanish Pronoun System

  Spanish pronouns have:
  - Gender: masculine/feminine (él/ella)
  - Number: singular/plural (él/ellos)
  - Case: subject/object (él/lo, ella/la)
  - Formality: formal/informal (tú/usted)

  ## Pro-drop

  Spanish allows null subjects, so coreference resolution must handle:
  - "Vino ayer" (He/she came yesterday) - no explicit subject
  - Verb conjugation indicates person/number

  ## Example

      iex> config = CoreferenceConfig.get()
      iex> config.pronouns.subject
      ["yo", "tú", "él", "ella", "usted", "nosotros", ...]
  """

  @doc """
  Returns Spanish coreference configuration for use by the generic resolver.
  """
  @spec get() :: map()
  def get do
    %{
      # Subject pronouns (nominative case)
      pronouns: %{
        subject: [
          # Singular
          "yo",
          "tú",
          "usted",
          "él",
          "ella",
          "ello",
          # Plural
          "nosotros",
          "nosotras",
          "vosotros",
          "vosotras",
          "ustedes",
          "ellos",
          "ellas"
        ],
        # Object pronouns (accusative case)
        object: [
          # Direct object
          "me",
          "te",
          "lo",
          "la",
          "nos",
          "os",
          "los",
          "las",
          # Indirect object
          "le",
          "les",
          # Reflexive
          "se"
        ],
        # Possessive pronouns
        possessive: [
          "mi",
          "mis",
          "tu",
          "tus",
          "su",
          "sus",
          "nuestro",
          "nuestra",
          "nuestros",
          "nuestras",
          "vuestro",
          "vuestra",
          "vuestros",
          "vuestras"
        ],
        # Demonstrative pronouns
        demonstrative: [
          "este",
          "esta",
          "esto",
          "estos",
          "estas",
          "ese",
          "esa",
          "eso",
          "esos",
          "esas",
          "aquel",
          "aquella",
          "aquello",
          "aquellos",
          "aquellas"
        ],
        # Relative pronouns
        relative: [
          "que",
          "quien",
          "quienes",
          "cual",
          "cuales",
          "cuyo",
          "cuya",
          "cuyos",
          "cuyas"
        ]
      },
      # Gender agreement rules
      gender: %{
        masculine: %{
          # Articles
          articles: ["el", "los", "un", "unos"],
          # Pronoun forms
          pronouns: ["él", "ellos", "lo", "los", "le", "les"],
          # Common endings
          endings: ["o", "os"]
        },
        feminine: %{
          # Articles
          articles: ["la", "las", "una", "unas"],
          # Pronoun forms
          pronouns: ["ella", "ellas", "la", "las", "le", "les"],
          # Common endings
          endings: ["a", "as"]
        }
      },
      # Number agreement rules
      number: %{
        singular: %{
          pronouns: ["yo", "tú", "usted", "él", "ella", "me", "te", "lo", "la", "le", "se"],
          articles: ["el", "la", "un", "una"],
          verb_endings: ["o", "as", "a", "es", "e"]
        },
        plural: %{
          pronouns: [
            "nosotros",
            "nosotras",
            "vosotros",
            "vosotras",
            "ustedes",
            "ellos",
            "ellas",
            "nos",
            "os",
            "los",
            "las",
            "les"
          ],
          articles: ["los", "las", "unos", "unas"],
          verb_endings: ["amos", "áis", "an", "emos", "éis", "en", "imos", "ís"]
        }
      },
      # Coreference resolution rules
      rules: %{
        # Prefer closer antecedents
        distance_weight: 0.5,
        # Require gender/number agreement
        agreement_required: true,
        # Handle pro-drop (null subjects)
        allow_null_subjects: true,
        # Maximum sentence distance for coreference
        max_sentence_distance: 3,
        # Prefer named entities as antecedents
        entity_preference: 0.8
      }
    }
  end

  @doc """
  Returns true if the given token is a Spanish pronoun.
  """
  @spec pronoun?(String.t()) :: boolean()
  def pronoun?(token) do
    config = get()
    normalized = String.downcase(token)

    Enum.any?([
      normalized in config.pronouns.subject,
      normalized in config.pronouns.object,
      normalized in config.pronouns.possessive,
      normalized in config.pronouns.demonstrative,
      normalized in config.pronouns.relative
    ])
  end

  @doc """
  Returns the gender of a Spanish token based on morphological features.
  """
  @spec get_gender(map()) :: :masculine | :feminine | :unknown
  def get_gender(%{morphology: %{gender: gender}}) when gender in [:masculine, :feminine],
    do: gender

  def get_gender(%{text: text}) do
    config = get()
    normalized = String.downcase(text)

    cond do
      normalized in config.gender.masculine.pronouns -> :masculine
      normalized in config.gender.feminine.pronouns -> :feminine
      String.ends_with?(normalized, config.gender.masculine.endings) -> :masculine
      String.ends_with?(normalized, config.gender.feminine.endings) -> :feminine
      true -> :unknown
    end
  end

  @doc """
  Returns the number of a Spanish token based on morphological features.
  """
  @spec get_number(map()) :: :singular | :plural | :unknown
  def get_number(%{morphology: %{number: number}}) when number in [:singular, :plural],
    do: number

  def get_number(%{text: text}) do
    config = get()
    normalized = String.downcase(text)

    cond do
      normalized in config.number.singular.pronouns -> :singular
      normalized in config.number.plural.pronouns -> :plural
      String.ends_with?(normalized, "s") -> :plural
      true -> :singular
    end
  end
end
