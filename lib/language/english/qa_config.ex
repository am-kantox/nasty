defmodule Nasty.Language.English.QAConfig do
  @moduledoc """
  English-specific configuration for Question Answering.

  Provides:
  - Question word mappings (who, what, when, etc.)
  - Auxiliary verbs for yes/no questions
  - Stop words for keyword extraction
  - Temporal patterns and keywords
  """

  # Question words with their types and expected answer types
  @question_words %{
    "who" => {:who, :person},
    "whom" => {:who, :person},
    "whose" => {:who, :person},
    "what" => {:what, :thing},
    "when" => {:when, :time},
    "where" => {:where, :location},
    "why" => {:why, :reason},
    "how" => {:how, :manner},
    "which" => {:which, :thing}
  }

  # Auxiliary verbs that indicate yes/no questions
  @auxiliary_verbs ~w(
    is are was were be been
    do does did
    can could
    will would
    shall should
    may might must
    have has had
  )

  # Stop words to exclude from keywords
  @stop_words ~w(
    a an the this that these those
    is are was were be been being
    have has had having
    do does did doing
    will would shall should may might can could must
    i me my mine you your yours he him his she her hers it its
    we us our ours they them their theirs
    in on at by for with from to of about
    and or but nor
  )

  # Content word POS tags
  @content_pos_tags [:noun, :verb, :adj, :propn, :adv]

  # Temporal expression patterns
  @temporal_patterns [
    ~r/^\d{4}$/,
    # 4-digit years
    ~r/^\d{1,2}$/
    # 1-2 digit numbers (potential days/months)
  ]

  # Temporal keywords
  @temporal_keywords ~w(
    year month day today yesterday tomorrow week
    monday tuesday wednesday thursday friday saturday sunday
    january february march april may june july august september october november december
  )

  @doc """
  Returns the map of question words to {type, answer_type}.
  """
  @spec question_words() :: map()
  def question_words, do: @question_words

  @doc """
  Returns the list of auxiliary verbs for yes/no questions.
  """
  @spec auxiliary_verbs() :: [String.t()]
  def auxiliary_verbs, do: @auxiliary_verbs

  @doc """
  Returns the list of stop words.
  """
  @spec stop_words() :: [String.t()]
  def stop_words, do: @stop_words

  @doc """
  Returns the list of POS tags for content words.
  """
  @spec content_pos_tags() :: [atom()]
  def content_pos_tags, do: @content_pos_tags

  @doc """
  Returns temporal expression patterns.
  """
  @spec temporal_patterns() :: [Regex.t()]
  def temporal_patterns, do: @temporal_patterns

  @doc """
  Returns temporal keywords.
  """
  @spec temporal_keywords() :: [String.t()]
  def temporal_keywords, do: @temporal_keywords

  @doc """
  Checks if an answer type expects a specific entity type.

  Used by question classifier to match expected answers with entities.
  """
  @spec expects_entity_type?(atom(), atom()) :: boolean()
  def expects_entity_type?(answer_type, entity_type) do
    case {answer_type, entity_type} do
      {:person, :person} -> true
      {:location, :gpe} -> true
      {:location, :loc} -> true
      {:thing, :org} -> true
      _ -> false
    end
  end

  @doc """
  Returns the complete configuration map for use with generic QA modules.
  """
  @spec config() :: map()
  def config do
    %{
      question_words: question_words(),
      auxiliary_verbs: auxiliary_verbs(),
      stop_words: stop_words(),
      content_pos_tags: content_pos_tags(),
      expects_entity_type?: &expects_entity_type?/2,
      temporal_patterns: temporal_patterns(),
      temporal_keywords: temporal_keywords()
    }
  end
end
