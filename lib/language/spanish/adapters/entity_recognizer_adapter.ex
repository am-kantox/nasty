defmodule Nasty.Language.Spanish.Adapters.EntityRecognizerAdapter do
  @moduledoc """
  Adapter that bridges Spanish.EntityRecognizer to generic Semantic.EntityRecognition.RuleBased.

  This adapter provides Spanish-specific configuration while delegating the core
  entity recognition algorithm to the language-agnostic implementation.

  ## Configuration

  Spanish-specific settings:
  - Name lexicons (common Spanish names from priv/languages/spanish/)
  - Place lexicons (Spanish cities, regions, countries)
  - Organization patterns (S.A., S.L., Ltda.)
  - Title patterns (Dr., Dra., Sr., Sra., Don, Doña)
  """

  alias Nasty.AST.{Entity, Token}
  alias Nasty.Semantic.EntityRecognition.RuleBased

  @doc """
  Recognizes named entities in Spanish text using rule-based extraction.

  Delegates to `Semantic.EntityRecognition.RuleBased` with Spanish configuration.

  ## Options

  - `:types` - List of entity types to extract (default: all)
  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:use_context` - Use context for disambiguation (default: true)

  ## Examples

      iex> {:ok, entities} = EntityRecognizerAdapter.recognize(spanish_tokens)
      {:ok, [%Entity{type: :PERSON, text: "María García"}, ...]}

      iex> {:ok, entities} = EntityRecognizerAdapter.recognize(tokens, types: [:PERSON, :ORG])
      {:ok, [%Entity{...}]}
  """
  @spec recognize([Token.t()], keyword()) :: {:ok, [Entity.t()]} | {:error, term()}
  def recognize(tokens, opts \\ []) do
    # Spanish-specific configuration
    config = %{
      language: :es,
      lexicons: load_spanish_lexicons(),
      patterns: spanish_patterns(),
      heuristics: spanish_heuristics(),
      titles: spanish_titles()
    }

    # Merge config with options
    full_opts = Keyword.merge([config: config], opts)

    # Delegate to generic rule-based entity recognition
    RuleBased.recognize(tokens, full_opts)
  end

  ## Private Functions

  # Load Spanish lexicons (names, places, organizations)
  defp load_spanish_lexicons do
    %{
      person_names: load_person_names(),
      places: load_places(),
      organizations: common_spanish_organizations()
    }
  end

  # Load Spanish person names from priv/ or use fallback
  defp load_person_names do
    # Try to load from file first
    path = Path.join(:code.priv_dir(:nasty), "languages/spanish/names.txt")

    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> MapSet.new()
    else
      # Fallback to common Spanish names
      MapSet.new([
        # Male names
        "José",
        "Juan",
        "Antonio",
        "Manuel",
        "Francisco",
        "David",
        "Daniel",
        "Carlos",
        "Miguel",
        "Alejandro",
        "Pedro",
        "Pablo",
        "Luis",
        "Javier",
        "Sergio",
        "Rafael",
        "Fernando",
        "Jorge",
        "Alberto",
        "Diego",
        # Female names
        "María",
        "Carmen",
        "Ana",
        "Isabel",
        "Dolores",
        "Pilar",
        "Teresa",
        "Rosa",
        "Francisca",
        "Laura",
        "Elena",
        "Cristina",
        "Paula",
        "Marta",
        "Lucía",
        "Sara",
        "Raquel",
        "Patricia",
        "Alicia",
        "Beatriz",
        # Common surnames
        "García",
        "Rodríguez",
        "González",
        "Fernández",
        "López",
        "Martínez",
        "Sánchez",
        "Pérez",
        "Gómez",
        "Martín",
        "Jiménez",
        "Ruiz",
        "Hernández",
        "Díaz",
        "Moreno",
        "Álvarez",
        "Muñoz",
        "Romero",
        "Alonso",
        "Gutiérrez"
      ])
    end
  end

  # Load Spanish places from priv/ or use fallback
  defp load_places do
    path = Path.join(:code.priv_dir(:nasty), "languages/spanish/places.txt")

    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> MapSet.new()
    else
      # Fallback to major Spanish-speaking cities and regions
      MapSet.new([
        # Spain
        "Madrid",
        "Barcelona",
        "Valencia",
        "Sevilla",
        "Zaragoza",
        "Málaga",
        "Murcia",
        "Palma",
        "Bilbao",
        "Alicante",
        "Granada",
        "España",
        "Cataluña",
        "Andalucía",
        "Galicia",
        "País Vasco",
        # Latin America
        "México",
        "Argentina",
        "Colombia",
        "Perú",
        "Venezuela",
        "Chile",
        "Ecuador",
        "Guatemala",
        "Cuba",
        "República Dominicana",
        "Bolivia",
        "Honduras",
        "Paraguay",
        "El Salvador",
        "Nicaragua",
        "Costa Rica",
        "Panamá",
        "Uruguay",
        # Major cities
        "Buenos Aires",
        "Ciudad de México",
        "Bogotá",
        "Lima",
        "Santiago",
        "Caracas",
        "Quito",
        "La Habana",
        "Montevideo",
        "San José"
      ])
    end
  end

  # Common Spanish organization suffixes and keywords
  defp common_spanish_organizations do
    MapSet.new([
      # Companies
      "Real Madrid",
      "Barcelona",
      "Telefónica",
      "Santander",
      "BBVA",
      "Repsol",
      "Iberdrola",
      "Inditex",
      # Generic patterns will be caught by patterns below
      "Gobierno",
      "Ministerio",
      "Universidad",
      "Ayuntamiento"
    ])
  end

  # Spanish entity recognition patterns
  defp spanish_patterns do
    %{
      # Person patterns
      person: [
        # Title + Name pattern
        ~r/^(Sr\.|Sra\.|Dr\.|Dra\.|Don|Doña|Prof\.|Lic\.)\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+/u,
        # Full name pattern (capitalized words)
        ~r/^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+$/u
      ],
      # Organization patterns
      organization: [
        # Company suffixes
        ~r/\b\w+\s+(S\.A\.|S\.L\.|Ltda\.|S\.A\.U\.|S\.R\.L\.)/u,
        # Government/institutions
        ~r/^(Ministerio|Gobierno|Ayuntamiento|Universidad|Instituto)\s+de/u,
        ~r/^Real\s+\w+/u
      ],
      # Place patterns
      place: [
        # City/region prefixes
        ~r/^(Ciudad\s+de|Provincia\s+de|Comunidad\s+de)\s+[A-ZÁÉÍÓÚÑ]/u,
        # Directional places
        ~r/^(Norte|Sur|Este|Oeste)\s+de\s+[A-ZÁÉÍÓÚÑ]/u
      ],
      # Date patterns
      date: [
        # Spanish date formats
        ~r/\d{1,2}\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)(\s+de\s+\d{4})?/iu,
        ~r/\d{1,2}\/\d{1,2}\/\d{2,4}/
      ],
      # Money patterns
      money: [
        # Euro amounts
        ~r/\d+([.,]\d+)?\s*€/,
        ~r/€\s*\d+([.,]\d+)?/,
        # Dollar amounts
        ~r/\$\s*\d+([.,]\d+)?/,
        ~r/\d+([.,]\d+)?\s*dólares/i,
        # Peso amounts
        ~r/\d+([.,]\d+)?\s*pesos/i
      ]
    }
  end

  # Spanish-specific heuristics
  defp spanish_heuristics do
    %{
      # Words that indicate a person follows
      person_indicators:
        MapSet.new([
          "presidente",
          "ministro",
          "ministra",
          "director",
          "directora",
          "alcalde",
          "alcaldesa",
          "rey",
          "reina",
          "príncipe",
          "princesa",
          "doctor",
          "doctora",
          "profesor",
          "profesora"
        ]),
      # Words that indicate an organization follows
      org_indicators:
        MapSet.new([
          "empresa",
          "compañía",
          "corporación",
          "grupo",
          "banco",
          "club",
          "asociación",
          "fundación",
          "partido",
          "equipo"
        ]),
      # Words that indicate a place follows
      place_indicators:
        MapSet.new([
          "ciudad",
          "provincia",
          "región",
          "comunidad",
          "país",
          "continente",
          "río",
          "monte",
          "sierra",
          "mar"
        ]),
      # Prepositions that often precede places
      place_prepositions: MapSet.new(["en", "de", "desde", "hacia", "a"])
    }
  end

  # Spanish titles that indicate person names
  defp spanish_titles do
    MapSet.new([
      "Sr.",
      "Sra.",
      "Srta.",
      "Dr.",
      "Dra.",
      "Prof.",
      "Profa.",
      "Lic.",
      "Ing.",
      "Don",
      "Doña",
      "Fray",
      "Sor"
    ])
  end
end
