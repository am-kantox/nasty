defmodule Nasty.Language.English.QuestionAnalyzer do
  @moduledoc """
  Analyzes questions to identify question type, expected answer type, and key information.

  Classifies questions by their interrogative word (who, what, when, where, why, how, which)
  and determines what type of answer is expected (person, location, time, etc.).
  """

  alias Nasty.AST.Token

  @typedoc """
  Question type based on interrogative word.
  """
  @type question_type :: :who | :what | :when | :where | :why | :how | :which | :yes_no

  @typedoc """
  Expected answer type for the question.
  """
  @type answer_type ::
          :person | :location | :time | :thing | :reason | :manner | :quantity | :boolean

  @type t :: %__MODULE__{
          type: question_type(),
          answer_type: answer_type(),
          focus: Token.t() | nil,
          keywords: [Token.t()],
          aux_verb: Token.t() | nil
        }

  defstruct type: nil, answer_type: nil, focus: nil, keywords: [], aux_verb: nil

  # Question words with their expected answer types
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
  @aux_verbs ~w(is are was were be been do does did can could will would shall should may might must have has had)

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

  @doc """
  Analyzes a question to extract type, expected answer type, and keywords.

  ## Examples

      iex> tokens = [
      ...>   %Token{text: "Who", pos_tag: :pron, lemma: "who"},
      ...>   %Token{text: "founded", pos_tag: :verb, lemma: "found"},
      ...>   %Token{text: "Google", pos_tag: :propn, lemma: "Google"}
      ...> ]
      iex> {:ok, analysis} = QuestionAnalyzer.analyze(tokens)
      iex> analysis.type
      :who
      iex> analysis.answer_type
      :person
  """
  @spec analyze([Token.t()]) :: {:ok, t()} | {:error, term()}
  def analyze([]), do: {:error, :empty_question}

  def analyze(tokens) do
    analysis = %__MODULE__{
      type: :unknown,
      answer_type: :thing,
      focus: nil,
      keywords: [],
      aux_verb: nil
    }

    # Detect question type
    analysis =
      case detect_question_word(tokens) do
        {:ok, qword, type, answer_type} ->
          %{analysis | type: type, answer_type: answer_type, focus: qword}

        :not_found ->
          # Check for yes/no question (starts with auxiliary)
          case detect_aux_question(tokens) do
            {:ok, aux} ->
              %{analysis | type: :yes_no, answer_type: :boolean, aux_verb: aux}

            :not_found ->
              analysis
          end
      end

    # Refine answer type based on question context
    analysis = refine_answer_type(analysis, tokens)

    # Extract keywords (content words)
    keywords = extract_keywords(tokens)

    {:ok, %{analysis | keywords: keywords}}
  end

  # Detect question word at start of sentence
  defp detect_question_word(tokens) do
    # Check first few tokens for question word
    tokens
    |> Enum.take(3)
    |> Enum.find_value(:not_found, fn token ->
      word = String.downcase(token.text)

      case Map.get(@question_words, word) do
        {type, answer_type} -> {:ok, token, type, answer_type}
        nil -> nil
      end
    end)
  end

  # Detect auxiliary verb at start (yes/no question)
  defp detect_aux_question([first | _rest]) do
    word = String.downcase(first.text)

    if word in @aux_verbs do
      {:ok, first}
    else
      :not_found
    end
  end

  defp detect_aux_question([]), do: :not_found

  # Refine answer type based on context
  defp refine_answer_type(%{type: :what} = analysis, tokens) do
    # Look for specific patterns:
    # "What time..." -> :time
    # "What year..." -> :time
    # "What place..." -> :location
    # "What is the name..." -> :person or :thing
    words = Enum.map(tokens, &String.downcase(&1.text))

    cond do
      "time" in words or "year" in words or "date" in words ->
        %{analysis | answer_type: :time}

      "place" in words or "location" in words or "city" in words ->
        %{analysis | answer_type: :location}

      "person" in words or "name" in words ->
        # Could be person or thing, keep as :thing for now
        analysis

      true ->
        analysis
    end
  end

  defp refine_answer_type(%{type: :how} = analysis, tokens) do
    # Look for patterns:
    # "How many..." -> :quantity
    # "How much..." -> :quantity
    # "How long..." -> :time or :quantity
    case tokens do
      [_how, second | _rest] ->
        word = String.downcase(second.text)

        case word do
          "many" -> %{analysis | answer_type: :quantity}
          "much" -> %{analysis | answer_type: :quantity}
          "long" -> %{analysis | answer_type: :quantity}
          "far" -> %{analysis | answer_type: :quantity}
          "old" -> %{analysis | answer_type: :quantity}
          _ -> analysis
        end

      _ ->
        analysis
    end
  end

  defp refine_answer_type(analysis, _tokens), do: analysis

  # Extract content words as keywords
  defp extract_keywords(tokens) do
    tokens
    |> Enum.filter(fn token ->
      word = String.downcase(token.text)
      # Include nouns, verbs, adjectives, proper nouns
      # Exclude stop words and punctuation
      is_content_word?(token.pos_tag) and word not in @stop_words
    end)
  end

  defp is_content_word?(pos) when pos in [:noun, :verb, :adj, :propn, :adv], do: true
  defp is_content_word?(_), do: false

  @doc """
  Checks if a question expects a specific entity type.

  ## Examples

      iex> analysis = %QuestionAnalyzer{type: :who, answer_type: :person}
      iex> QuestionAnalyzer.expects_entity_type?(analysis, :person)
      true
      iex> QuestionAnalyzer.expects_entity_type?(analysis, :org)
      false
  """
  @spec expects_entity_type?(t(), atom()) :: boolean()
  def expects_entity_type?(%__MODULE__{answer_type: answer_type}, entity_type) do
    case {answer_type, entity_type} do
      {:person, :person} -> true
      {:location, :gpe} -> true
      {:location, :loc} -> true
      {:thing, :org} -> true
      _ -> false
    end
  end

  @doc """
  Returns a human-readable description of the question analysis.

  ## Examples

      iex> analysis = %QuestionAnalyzer{type: :who, answer_type: :person, keywords: []}
      iex> QuestionAnalyzer.describe(analysis)
      "WHO question expecting PERSON answer"
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{type: type, answer_type: answer_type}) do
    type_str = type |> to_string() |> String.upcase()
    answer_str = answer_type |> to_string() |> String.upcase()
    "#{type_str} question expecting #{answer_str} answer"
  end
end
