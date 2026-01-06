defmodule Nasty.Language.English.Morphology do
  @moduledoc """
  Morphological analyzer for English tokens.

  Provides lemmatization (finding the base form of words) using:
  - Dictionary lookup for irregular forms
  - Rule-based suffixremoval for regular forms

  ## Examples

      iex> alias Nasty.Language.English.{Tokenizer, POSTagger, Morphology}
      iex> {:ok, tokens} = Tokenizer.tokenize("running")
      iex> {:ok, tagged} = POSTagger.tag_pos(tokens)
      iex> {:ok, analyzed} = Morphology.analyze(tagged)
      iex> hd(analyzed).lemma
      "run"
  """

  alias Nasty.AST.Token

  @doc """
  Analyzes tokens to add lemma and morphological features.

  Updates each token with:
  - `:lemma` - Base form of the word
  - `:morphology` - Map of morphological features (tense, number, etc.)

  ## Parameters

    - `tokens` - List of Token structs (with POS tags)

  ## Returns

    - `{:ok, tokens}` - Tokens with lemma and morphology fields updated
  """
  @spec analyze([Token.t()]) :: {:ok, [Token.t()]}
  def analyze(tokens) do
    analyzed = Enum.map(tokens, &analyze_token/1)
    {:ok, analyzed}
  end

  @doc """
  Lemmatizes a word based on its part-of-speech tag.

  Returns the base form (lemma) of a word using dictionary lookup for irregular
  forms and rule-based suffix removal for regular forms.

  ## Parameters

    - `word` - The word to lemmatize (lowercase string)
    - `pos_tag` - Part-of-speech tag atom (`:verb`, `:noun`, `:adj`, etc.)

  ## Returns

    - `String.t()` - The lemmatized form of the word

  ## Examples

      iex> Nasty.Language.English.Morphology.lemmatize("running", :verb)
      "run"

      iex> Nasty.Language.English.Morphology.lemmatize("cats", :noun)
      "cat"

      iex> Nasty.Language.English.Morphology.lemmatize("better", :adj)
      "good"
  """
  @spec lemmatize(String.t(), atom()) :: String.t()
  def lemmatize(word, pos_tag) do
    # Try irregular forms first
    irregular_lemma(word, pos_tag) || rule_based_lemma(word, pos_tag) || word
  end

  ## Private Functions

  # Analyze a single token
  defp analyze_token(token) do
    # Skip punctuation and numbers
    if token.pos_tag in [:punct, :num] do
      %{token | lemma: token.text}
    else
      lowercase = String.downcase(token.text)
      lemma = lemmatize(lowercase, token.pos_tag)
      morph = extract_morphology(token.text, lowercase, lemma, token.pos_tag)

      %{token | lemma: lemma, morphology: morph}
    end
  end

  # Irregular verbs, nouns, adjectives
  defp irregular_lemma(word, :verb) do
    irregular_verbs()[word]
  end

  defp irregular_lemma(word, :noun) do
    irregular_nouns()[word]
  end

  defp irregular_lemma(word, :adj) do
    irregular_adjectives()[word]
  end

  defp irregular_lemma(_word, _pos), do: nil

  # Rule-based lemmatization
  defp rule_based_lemma(word, :verb) do
    cond do
      String.ends_with?(word, "ing") ->
        stem_ing(word)

      String.ends_with?(word, "ed") ->
        stem_ed(word)

      String.ends_with?(word, "s") and String.length(word) > 2 ->
        # Third person singular
        String.slice(word, 0..-2//1)

      true ->
        word
    end
  end

  defp rule_based_lemma(word, :noun) do
    cond do
      String.ends_with?(word, "ies") and String.length(word) > 4 ->
        # flies -> fly
        String.slice(word, 0..-4//1) <> "y"

      String.ends_with?(word, "es") and String.length(word) > 3 ->
        # boxes -> box, dishes -> dish
        base = String.slice(word, 0..-3//1)

        if String.ends_with?(base, ~w(s x z ch sh)) do
          base
        else
          String.slice(word, 0..-2//1)
        end

      String.ends_with?(word, "s") and String.length(word) > 2 ->
        # cats -> cat
        String.slice(word, 0..-2//1)

      true ->
        word
    end
  end

  defp rule_based_lemma(word, :adj) do
    cond do
      String.ends_with?(word, "est") and String.length(word) > 4 ->
        # fastest -> fast
        stem_superlative(word)

      String.ends_with?(word, "er") and String.length(word) > 3 ->
        # faster -> fast
        stem_comparative(word)

      true ->
        word
    end
  end

  defp rule_based_lemma(word, _pos), do: word

  # Stem -ing forms
  defp stem_ing(word) do
    base = String.slice(word, 0..-4//1)

    if String.length(base) >= 2 and String.at(base, -1) == String.at(base, -2) and
         String.at(base, -1) not in ~w(s),
       # running -> run (doubled consonant)
       do: String.slice(base, 0..-2//1),
       # making -> make (drop e before ing)
       else: base
  end

  # Stem -ed forms
  defp stem_ed(word) do
    base = String.slice(word, 0..-3//1)

    cond do
      # stopped -> stop (doubled consonant)
      String.length(base) >= 2 and
          String.at(base, -1) == String.at(base, -2) ->
        String.slice(base, 0..-2//1)

      # liked -> like (add e back)
      String.ends_with?(base, ~w(c g v)) ->
        base <> "e"

      true ->
        base
    end
  end

  # Stem comparative adjectives (-er)
  defp stem_comparative(word) do
    base = String.slice(word, 0..-3//1)

    if String.length(base) >= 2 and String.at(base, -1) == String.at(base, -2) do
      String.slice(base, 0..-2//1)
    else
      base
    end
  end

  # Stem superlative adjectives (-est)
  defp stem_superlative(word) do
    base = String.slice(word, 0..-4//1)

    if String.length(base) >= 2 and String.at(base, -1) == String.at(base, -2) do
      String.slice(base, 0..-2//1)
    else
      base
    end
  end

  # Extract morphological features
  defp extract_morphology(original, _lowercase, lemma, pos_tag) do
    features = %{}

    features =
      if pos_tag == :verb do
        Map.merge(features, extract_verb_features(original, lemma))
      else
        features
      end

    features =
      if pos_tag == :noun do
        Map.merge(features, extract_noun_features(original, lemma))
      else
        features
      end

    features =
      if pos_tag == :adj do
        Map.merge(features, extract_adj_features(original, lemma))
      else
        features
      end

    features
  end

  defp extract_verb_features(word, lemma) do
    lowercase = String.downcase(word)

    cond do
      String.ends_with?(lowercase, "ing") ->
        %{tense: :present, aspect: :progressive}

      String.ends_with?(lowercase, "ed") ->
        %{tense: :past}

      lowercase != lemma and String.ends_with?(lowercase, "s") ->
        %{tense: :present, person: 3, number: :singular}

      true ->
        %{tense: :present}
    end
  end

  defp extract_noun_features(word, lemma) do
    lowercase = String.downcase(word)

    if lowercase != lemma do
      %{number: :plural}
    else
      %{number: :singular}
    end
  end

  defp extract_adj_features(word, lemma) do
    lowercase = String.downcase(word)

    cond do
      String.ends_with?(lowercase, "est") and lowercase != lemma ->
        %{degree: :superlative}

      String.ends_with?(lowercase, "er") and lowercase != lemma ->
        %{degree: :comparative}

      true ->
        %{degree: :positive}
    end
  end

  ## Irregular Forms Dictionaries

  defp irregular_verbs do
    %{
      # be
      "am" => "be",
      "is" => "be",
      "are" => "be",
      "was" => "be",
      "were" => "be",
      "been" => "be",
      "being" => "be",

      # have
      "has" => "have",
      "had" => "have",
      "having" => "have",

      # do
      "does" => "do",
      "did" => "do",
      "done" => "do",
      "doing" => "do",

      # go
      "goes" => "go",
      "went" => "go",
      "gone" => "go",
      "going" => "go",

      # common irregulars
      "ate" => "eat",
      "eaten" => "eat",
      "eating" => "eat",
      "ran" => "run",
      "running" => "run",
      "came" => "come",
      "coming" => "come",
      "saw" => "see",
      "seen" => "see",
      "seeing" => "see",
      "made" => "make",
      "making" => "make",
      "took" => "take",
      "taken" => "take",
      "taking" => "take",
      "got" => "get",
      "gotten" => "get",
      "getting" => "get",
      "gave" => "give",
      "given" => "give",
      "giving" => "give",
      "said" => "say",
      "saying" => "say",
      "knew" => "know",
      "known" => "know",
      "knowing" => "know",
      "thought" => "think",
      "thinking" => "think",
      "felt" => "feel",
      "feeling" => "feel",
      "left" => "leave",
      "leaving" => "leave",
      "kept" => "keep",
      "keeping" => "keep",
      "meant" => "mean",
      "meaning" => "mean",
      "told" => "tell",
      "telling" => "tell",
      "found" => "find",
      "finding" => "find",
      "brought" => "bring",
      "bringing" => "bring",
      "began" => "begin",
      "begun" => "begin",
      "beginning" => "begin",
      "wrote" => "write",
      "written" => "write",
      "writing" => "write",
      "stood" => "stand",
      "standing" => "stand",
      "heard" => "hear",
      "hearing" => "hear",
      "let" => "let",
      "letting" => "let",
      "put" => "put",
      "putting" => "put",
      "set" => "set",
      "setting" => "set"
    }
  end

  defp irregular_nouns do
    %{
      "children" => "child",
      "men" => "man",
      "women" => "woman",
      "people" => "person",
      "teeth" => "tooth",
      "feet" => "foot",
      "mice" => "mouse",
      "geese" => "goose",
      "oxen" => "ox",
      "sheep" => "sheep",
      "deer" => "deer",
      "fish" => "fish"
    }
  end

  defp irregular_adjectives do
    %{
      "better" => "good",
      "best" => "good",
      "worse" => "bad",
      "worst" => "bad",
      "more" => "much",
      "most" => "much",
      "less" => "little",
      "least" => "little",
      "further" => "far",
      "furthest" => "far",
      "farther" => "far",
      "farthest" => "far"
    }
  end
end
