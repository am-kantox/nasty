defmodule Nasty.Language.Spanish.QAConfig do
  @moduledoc """
  Configuration for Spanish Question Answering (QA).

  Provides Spanish question patterns, answer type mappings, and
  keywords for the generic QA engine.

  ## Spanish Question Types

  - Qué (what): entities, objects
  - Quién (who): people
  - Dónde (where): locations
  - Cuándo (when): times, dates
  - Por qué (why): reasons, causes
  - Cómo (how): manner, methods
  - Cuál (which): choices
  - Cuánto (how much/many): quantities

  ## Example

      iex> config = QAConfig.get()
      iex> config.question_patterns.who
      ["¿quién", "quien", "quiénes", "quienes"]
  """

  @doc """
  Returns Spanish QA configuration for use by the generic QA engine.
  """
  @spec config() :: map()
  def config do
    %{
      # Question patterns for each question type
      question_patterns: %{
        # Who questions (person)
        who: [
          "¿quién",
          "quien",
          "quiénes",
          "quienes"
        ],
        # What questions (thing, entity)
        what: [
          "¿qué",
          "que",
          "cuál",
          "cuáles"
        ],
        # Where questions (location)
        where: [
          "¿dónde",
          "donde",
          "adónde",
          "de dónde"
        ],
        # When questions (time)
        when: [
          "¿cuándo",
          "cuando",
          "en qué año",
          "en qué fecha"
        ],
        # Why questions (reason)
        why: [
          "¿por qué",
          "por que",
          "para qué"
        ],
        # How questions (manner)
        how: [
          "¿cómo",
          "como",
          "de qué manera",
          "de qué forma"
        ],
        # How much/many questions (quantity)
        how_many: [
          "¿cuánto",
          "cuanto",
          "¿cuánta",
          "cuanta",
          "¿cuántos",
          "cuantos",
          "¿cuántas",
          "cuantas"
        ],
        # Which questions (choice)
        which: [
          "¿cuál",
          "cual",
          "¿cuáles",
          "cuales"
        ],
        # Yes/no questions (boolean)
        boolean: [
          "¿es",
          "¿son",
          "¿está",
          "¿están",
          "¿fue",
          "¿fueron",
          "¿puede",
          "¿pueden",
          "¿debe",
          "¿deben"
        ]
      },
      # Answer type mappings
      answer_types: %{
        who: :person,
        # Named entity: person
        what: :entity,
        # Any entity
        where: :location,
        # Named entity: location
        when: :date,
        # Named entity: date/time
        why: :reason,
        # Clause or phrase
        how: :manner,
        # Clause or phrase
        how_many: :number,
        # Number
        which: :entity,
        # Entity from set
        boolean: :boolean
        # Yes/no
      },
      # Keywords that help identify answer spans
      answer_keywords: %{
        person: [
          # Titles
          "sr",
          "sra",
          "dr",
          "dra",
          "prof",
          # Roles
          "presidente",
          "rey",
          "reina",
          "ministro",
          "director",
          "actor",
          "actriz"
        ],
        location: [
          # Place types
          "ciudad",
          "país",
          "región",
          "provincia",
          "capital",
          "pueblo",
          # Prepositions
          "en",
          "a",
          "de",
          "desde",
          "hasta"
        ],
        date: [
          # Time words
          "año",
          "mes",
          "día",
          "fecha",
          "siglo",
          # Days
          "lunes",
          "martes",
          "miércoles",
          "jueves",
          "viernes",
          "sábado",
          "domingo",
          # Months
          "enero",
          "febrero",
          "marzo",
          "abril",
          "mayo",
          "junio",
          "julio",
          "agosto",
          "septiembre",
          "octubre",
          "noviembre",
          "diciembre"
        ],
        reason: [
          # Causal markers
          "porque",
          "ya que",
          "puesto que",
          "debido a",
          "a causa de",
          "por",
          "para"
        ],
        manner: [
          # Manner markers
          "con",
          "mediante",
          "por medio de",
          "a través de",
          "de forma",
          "de manera"
        ],
        number: [
          # Quantity words
          "número",
          "cantidad",
          "total",
          "suma",
          "muchos",
          "pocos",
          "varios"
        ]
      },
      # Stop words to filter out when matching questions to context
      stop_words: [
        "el",
        "la",
        "los",
        "las",
        "un",
        "una",
        "unos",
        "unas",
        "de",
        "a",
        "en",
        "y",
        "o",
        "pero",
        "con",
        "por",
        "para",
        "que"
      ]
    }
  end

  @doc """
  Identifies the question type from a Spanish question string.
  """
  @spec identify_question_type(String.t()) :: atom() | nil
  def identify_question_type(question) do
    conf = config()
    normalized = String.downcase(question)

    Enum.find_value(conf.question_patterns, fn {type, patterns} ->
      if Enum.any?(patterns, &String.starts_with?(normalized, &1)), do: type
    end)
  end

  @doc """
  Returns the expected answer type for a question type.
  """
  @spec get_answer_type(atom()) :: atom()
  def get_answer_type(question_type) do
    conf = config()
    Map.get(conf.answer_types, question_type, :entity)
  end
end
