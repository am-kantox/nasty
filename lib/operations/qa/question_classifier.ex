defmodule Nasty.Operations.QA.QuestionClassifier do
  @moduledoc """
  Generic question classification for Question Answering systems.

  Classifies questions by interrogative word (who, what, when, where, why, how)
  and determines expected answer type (person, location, time, etc.).

  Language-specific patterns (question words, stop words) are provided via configuration.
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

  @typedoc """
  Language configuration for question classification.

  Required fields:
  - `question_words` - Map of interrogative words to {type, answer_type}
  - `auxiliary_verbs` - List of auxiliary verbs for yes/no questions
  - `stop_words` - Words to exclude from keywords
  - `content_pos_tags` - POS tags for content words
  - `expects_entity_type?` - Function to check if answer type expects entity type
  """
  @type language_config :: %{
          question_words: map(),
          auxiliary_verbs: [String.t()],
          stop_words: [String.t()],
          content_pos_tags: [atom()],
          expects_entity_type?: (answer_type(), atom() -> boolean())
        }

  @doc """
  Classifies a question from its tokens.

  Returns `{:ok, analysis}` with question type, expected answer type,
  focus word, and keywords.
  """
  @spec classify([Token.t()], language_config(), keyword()) :: {:ok, t()} | {:error, term()}
  def classify(tokens, config, opts \\ [])
  def classify([], _config, _opts), do: {:error, :empty_question}

  def classify(tokens, config, _opts) do
    analysis = %__MODULE__{
      type: :unknown,
      answer_type: :thing,
      focus: nil,
      keywords: [],
      aux_verb: nil
    }

    # Detect question type
    analysis =
      case detect_question_word(tokens, config) do
        {:ok, qword, type, answer_type} ->
          %{analysis | type: type, answer_type: answer_type, focus: qword}

        :not_found ->
          # Check for yes/no question (starts with auxiliary)
          case detect_aux_question(tokens, config) do
            {:ok, aux} ->
              %{analysis | type: :yes_no, answer_type: :boolean, aux_verb: aux}

            :not_found ->
              analysis
          end
      end

    # Refine answer type based on question context
    analysis = refine_answer_type(analysis, tokens, config)

    # Extract keywords (content words)
    keywords = extract_keywords(tokens, config)

    {:ok, %{analysis | keywords: keywords}}
  end

  @doc """
  Checks if a question expects a specific entity type.
  """
  @spec expects_entity_type?(t(), atom(), language_config()) :: boolean()
  def expects_entity_type?(%__MODULE__{answer_type: answer_type}, entity_type, config) do
    config.expects_entity_type?.(answer_type, entity_type)
  end

  @doc """
  Returns a human-readable description of the question analysis.
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{type: type, answer_type: answer_type}) do
    type_str = type |> to_string() |> String.upcase()
    answer_str = answer_type |> to_string() |> String.upcase()
    "#{type_str} question expecting #{answer_str} answer"
  end

  # Detect question word at start of sentence
  defp detect_question_word(tokens, config) do
    question_words = config.question_words

    # Check first few tokens for question word
    tokens
    |> Enum.take(3)
    |> Enum.find_value(:not_found, fn token ->
      word = String.downcase(token.text)

      case Map.get(question_words, word) do
        {type, answer_type} -> {:ok, token, type, answer_type}
        nil -> nil
      end
    end)
  end

  # Detect auxiliary verb at start (yes/no question)
  defp detect_aux_question([first | _rest], config) do
    word = String.downcase(first.text)
    aux_verbs = config.auxiliary_verbs

    if word in aux_verbs do
      {:ok, first}
    else
      :not_found
    end
  end

  defp detect_aux_question([], _config), do: :not_found

  # Refine answer type based on context
  defp refine_answer_type(%{type: :what} = analysis, tokens, _config) do
    # Look for specific patterns:
    # "What time..." -> :time
    # "What year..." -> :time
    # "What place..." -> :location
    words = Enum.map(tokens, &String.downcase(&1.text))

    cond do
      "time" in words or "year" in words or "date" in words ->
        %{analysis | answer_type: :time}

      "place" in words or "location" in words or "city" in words ->
        %{analysis | answer_type: :location}

      "person" in words or "name" in words ->
        analysis

      true ->
        analysis
    end
  end

  defp refine_answer_type(%{type: :how} = analysis, tokens, _config) do
    # Look for patterns:
    # "How many..." -> :quantity
    # "How much..." -> :quantity
    # "How long..." -> :time or :quantity
    case tokens do
      [_how, second | _rest] ->
        word = String.downcase(second.text)

        case word do
          w when w in ["many", "much", "long", "far", "old"] ->
            %{analysis | answer_type: :quantity}

          _ ->
            analysis
        end

      _ ->
        analysis
    end
  end

  defp refine_answer_type(analysis, _tokens, _config), do: analysis

  # Extract content words as keywords
  defp extract_keywords(tokens, config) do
    stop_words = config.stop_words
    content_pos_tags = config.content_pos_tags

    tokens
    |> Enum.filter(fn token ->
      word = String.downcase(token.text)
      # Include content words, exclude stop words
      token.pos_tag in content_pos_tags and word not in stop_words
    end)
  end
end
