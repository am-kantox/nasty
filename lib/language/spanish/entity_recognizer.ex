defmodule Nasty.Language.Spanish.EntityRecognizer do
  @moduledoc """
  Recognizes named entities in Spanish text.

  Uses rule-based patterns to identify:
  - PERSON: names (Juan García, María López)
  - LOCATION: cities, countries (Madrid, España, Barcelona, Cataluña)
  - ORGANIZATION: companies, institutions (Banco de España, Real Madrid)
  - DATE: temporal expressions (lunes, 15 de enero, 2024)
  - MONEY: currency amounts (100 euros, $50, 25€)
  - PERCENT: percentages (25%, 3.5 por ciento)

  ## Spanish-Specific Features

  - Spanish name patterns (compound surnames: García Márquez)
  - Spanish date formats (15 de enero de 2024)
  - Euro currency symbols (€)
  - Spanish organizational indicators (S.A., S.L., Gobierno de)

  ## Example

      iex> doc = parse("Juan García visitó Madrid el lunes")
      iex> EntityRecognizer.recognize(doc)
      [
        %Entity{type: :person, text: "Juan García", span: ...},
        %Entity{type: :location, text: "Madrid", span: ...},
        %Entity{type: :date, text: "el lunes", span: ...}
      ]
  """

  alias Nasty.AST.{Document, Entity}
  alias Nasty.Semantic.EntityRecognition.RuleBased

  @doc """
  Recognizes named entities in a Spanish document.

  Delegates to the generic rule-based recognizer with Spanish-specific patterns.
  """
  @spec recognize(Document.t()) :: [Entity.t()]
  def recognize(%Document{} = doc) do
    RuleBased.recognize(doc, spanish_patterns())
  end

  # Spanish-specific entity recognition patterns
  defp spanish_patterns do
    %{
      person: [
        # Spanish names with titles
        ~r/\b(?:Sr\.|Sra\.|Dr\.|Dra\.|Prof\.)\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)+\b/u,
        # Compound Spanish surnames (García Márquez, López de Ayala)
        ~r/\b[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\s+(?:de\s+)?[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\b/u,
        # Simple names
        ~r/\b[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\b/u
      ],
      location: [
        # Spanish cities and regions
        ~r/\b(?:Madrid|Barcelona|Valencia|Sevilla|Zaragoza|Málaga|Murcia|Palma|Bilbao|Alicante|Córdoba|Valladolid|Vigo|Gijón|Granada|Cataluña|Andalucía|País\s+Vasco|Galicia|Castilla\s+y\s+León)\b/u,
        # Countries
        ~r/\b(?:España|Argentina|México|Colombia|Chile|Perú|Venezuela|Ecuador|Guatemala|Cuba|Bolivia|Honduras|Paraguay|Uruguay|Costa\s+Rica|Panamá|Puerto\s+Rico|República\s+Dominicana)\b/u,
        # Cities with "de" (Ciudad de México, San Juan de Puerto Rico)
        ~r/\b[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+de\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)+\b/u
      ],
      organization: [
        # Spanish companies (S.A., S.L.)
        ~r/\b[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)*\s+(?:S\.A\.|S\.L\.|S\.L\.U\.|S\.Coop\.)\b/u,
        # Government organizations
        ~r/\b(?:Gobierno\s+de|Ministerio\s+de|Consejo\s+de|Tribunal\s+de)\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[a-záéíóúñ]+)*\b/u,
        # Universities and institutions
        ~r/\bUniversidad\s+(?:de\s+)?[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)*\b/u,
        # Banks and financial institutions
        ~r/\bBanco\s+(?:de\s+)?[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)*\b/u,
        # Well-known Spanish organizations
        ~r/\b(?:Real\s+Madrid|FC\s+Barcelona|Banco\s+de\s+España|BBVA|Telefónica|Repsol|Inditex)\b/u
      ],
      date: [
        # Spanish day names
        ~r/\b(?:el\s+)?(?:lunes|martes|miércoles|jueves|viernes|sábado|domingo)\b/u,
        # Full dates (15 de enero de 2024)
        ~r/\b\d{1,2}\s+de\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+(?:de\s+)?\d{4}\b/u,
        # Month year (enero de 2024, enero 2024)
        ~r/\b(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+(?:de\s+)?\d{4}\b/u,
        # Year
        ~r/\b(?:año\s+)?\d{4}\b/u,
        # Relative dates
        ~r/\b(?:hoy|ayer|mañana|anteayer|pasado\s+mañana)\b/u,
        # Time periods
        ~r/\b(?:este|esta|próximo|próxima|último|última)\s+(?:año|mes|semana|lunes|martes|miércoles|jueves|viernes|sábado|domingo)\b/u
      ],
      money: [
        # Euro amounts (100 euros, 100€, 100 €)
        ~r/\b\d+(?:[.,]\d+)?\s*(?:euros?|€)\b/u,
        # Dollar amounts ($100, 100 dólares)
        ~r/\b(?:\$|USD)\s*\d+(?:[.,]\d+)?|\b\d+(?:[.,]\d+)?\s*(?:dólares?|USD)\b/u,
        # Peso amounts (100 pesos)
        ~r/\b\d+(?:[.,]\d+)?\s*pesos?\b/u,
        # General currency pattern
        ~r/\b\d+(?:[.,]\d+)?\s*(?:euros?|dólares?|pesos?|libras?)\b/u
      ],
      percent: [
        # Percentage symbol (25%, 3.5%)
        ~r/\b\d+(?:[.,]\d+)?\s*%\b/u,
        # Spelled out (25 por ciento, 3.5 por ciento)
        ~r/\b\d+(?:[.,]\d+)?\s*por\s+ciento\b/u
      ]
    }
  end
end
