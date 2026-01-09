defmodule Nasty.Language.Catalan.Morphology do
  @moduledoc """
  Morphological analyzer for Catalan tokens.

  Provides lemmatization (finding the base form of words) using:
  - Dictionary lookup for irregular forms
  - Rule-based suffix removal for regular conjugations/declensions

  ## Catalan-Specific Features

  - Verb lemmatization: all conjugations → infinitive (-ar, -re, -ir)
  - Noun lemmatization: plural → singular, gender variations
  - Adjective lemmatization: gender/number agreement
  - Morphological features: gender, number, tense, mood, person
  - Clitic handling (em, et, es, el, la, etc.)
  """

  alias Nasty.AST.Token

  @doc """
  Analyzes tokens to add lemma and morphological features.

  Updates each token with:
  - `:lemma` - Base form of the word (infinitive for verbs, singular for nouns)
  - `:morphology` - Map of morphological features (gender, number, tense, etc.)

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
  Lemmatizes a Catalan word based on its part-of-speech tag.

  Returns the base form (lemma) of a word using dictionary lookup for irregular
  forms and rule-based suffix removal for regular forms.

  ## Parameters

    - `word` - The word to lemmatize (lowercase string)
    - `pos_tag` - Part-of-speech tag atom (`:verb`, `:noun`, `:adj`, etc.)

  ## Returns

    - `String.t()` - The lemmatized form of the word
  """
  @spec lemmatize(String.t(), atom()) :: String.t()
  def lemmatize(word, pos_tag) do
    irregular_lemma(word, pos_tag) || rule_based_lemma(word, pos_tag) || word
  end

  ## Private Functions

  defp analyze_token(token) do
    if token.pos_tag in [:punct, :num] do
      %{token | lemma: token.text}
    else
      lowercase = String.downcase(token.text)
      lemma = lemmatize(lowercase, token.pos_tag)
      morph = extract_morphology(token.text, lowercase, lemma, token.pos_tag)

      %{token | lemma: lemma, morphology: morph}
    end
  end

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

  # Rule-based lemmatization for Catalan verbs
  # credo:disable-for-lines:150
  defp rule_based_lemma(word, :verb) do
    case String.reverse(word) do
      # Gerund: -ant, -ent, -int → -ar, -re, -ir
      "tna" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "tne" <> rest ->
        rest |> String.reverse() |> Kernel.<>("re")

      "tni" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ir")

      # Past participle: -at, -ut, -it → -ar, -re, -ir
      "ta" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "tu" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("re")

      "ti" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("ir")

      # Present tense -ar verbs (parlo, parles, parla, parlem, parleu, parlen)
      <<"o", rest::binary>> when byte_size(rest) >= 2 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "se" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      <<"a", rest::binary>> when byte_size(rest) >= 2 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "me" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "ue" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "ne" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      # Present tense -re verbs (visc, vius, viu, vivim, viviu, viuen)
      "csiv" ->
        "viure"

      "suiv" ->
        "viure"

      "uiv" ->
        "viure"

      "miviv" ->
        "viure"

      "uiviv" ->
        "viure"

      "neuiv" ->
        "viure"

      # Preterite (perfet simple)
      <<"í", rest::binary>> ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "sera" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      <<"à", rest::binary>> ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "merà" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "uerà" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "nera" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      # Imperfect (imperfet)
      "ava" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "seva" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "mevà" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "uevà" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "neva" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "ai" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("re")

      "sei" <> rest ->
        rest |> String.reverse() |> Kernel.<>("re")

      "meí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("re")

      "ueí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("re")

      "nei" <> rest ->
        rest |> String.reverse() |> Kernel.<>("re")

      # Future
      <<"ér", rest::binary>> ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "sàr" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      <<"àr", rest::binary>> ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "mer" <> rest when byte_size(rest) >= 2 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "uer" <> rest when byte_size(rest) >= 2 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "nar" <> rest when byte_size(rest) >= 2 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      # Conditional
      "air" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "seir" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "meír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "ueír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "neir" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      _ ->
        word
    end
  end

  # Rule-based lemmatization for Catalan nouns
  defp rule_based_lemma(word, :noun) do
    cond do
      String.ends_with?(word, "ions") ->
        String.slice(word, 0..-4//1)

      String.ends_with?(word, "ces") ->
        String.slice(word, 0..-4//1) <> "ç"

      String.ends_with?(word, "es") and String.length(word) > 3 ->
        String.slice(word, 0..-3//1)

      String.ends_with?(word, "s") and String.length(word) > 2 ->
        String.slice(word, 0..-2//1)

      true ->
        word
    end
  end

  # Rule-based lemmatization for Catalan adjectives
  defp rule_based_lemma(word, :adj) do
    cond do
      String.ends_with?(word, "a") and String.length(word) > 2 ->
        String.slice(word, 0..-2//1)

      String.ends_with?(word, "es") ->
        String.slice(word, 0..-3//1)

      String.ends_with?(word, "s") and String.length(word) > 2 ->
        String.slice(word, 0..-2//1)

      true ->
        word
    end
  end

  defp rule_based_lemma(word, _pos), do: word

  # Extract morphological features
  defp extract_morphology(_original, lowercase, lemma, pos_tag) do
    features = %{}

    features =
      if pos_tag == :verb do
        Map.merge(features, extract_verb_features(lowercase, lemma))
      else
        features
      end

    features =
      if pos_tag == :noun do
        Map.merge(features, extract_noun_features(lowercase, lemma))
      else
        features
      end

    features =
      if pos_tag == :adj do
        Map.merge(features, extract_adj_features(lowercase, lemma))
      else
        features
      end

    features
  end

  defp extract_verb_features(word, _lemma) do
    cond do
      String.ends_with?(word, "ant") or String.ends_with?(word, "ent") or
          String.ends_with?(word, "int") ->
        %{tense: :present, aspect: :progressive, mood: :indicative}

      String.ends_with?(word, "at") or String.ends_with?(word, "ut") or
          String.ends_with?(word, "it") ->
        %{tense: :past, aspect: :perfective}

      String.ends_with?(word, ["ria", "ries", "ríem", "ríeu", "rien"]) ->
        %{tense: :conditional, mood: :conditional}

      String.ends_with?(word, ["ré", "ràs", "rà", "rem", "reu", "ran"]) ->
        %{tense: :future, mood: :indicative}

      String.ends_with?(word, ["í", "ares", "à", "àrem", "àreu", "aren"]) ->
        %{tense: :past, mood: :indicative}

      String.ends_with?(word, [
        "ava",
        "aves",
        "àvem",
        "àveu",
        "aven",
        "ia",
        "ies",
        "íem",
        "íeu",
        "ien"
      ]) ->
        %{tense: :imperfect, mood: :indicative}

      true ->
        %{tense: :present, mood: :indicative}
    end
  end

  defp extract_noun_features(word, lemma) do
    features = %{}

    features =
      cond do
        String.ends_with?(word, "a") or String.ends_with?(word, "es") ->
          Map.put(features, :gender, :feminine)

        String.ends_with?(word, "s") ->
          Map.put(features, :gender, :masculine)

        true ->
          features
      end

    features =
      if word != lemma and (String.ends_with?(word, "s") or String.ends_with?(word, "es")) do
        Map.put(features, :number, :plural)
      else
        Map.put(features, :number, :singular)
      end

    features
  end

  defp extract_adj_features(word, lemma) do
    features = %{}

    features =
      cond do
        String.ends_with?(word, "a") or String.ends_with?(word, "es") ->
          Map.put(features, :gender, :feminine)

        true ->
          features
      end

    features =
      if word != lemma and (String.ends_with?(word, "s") or String.ends_with?(word, "es")) do
        Map.put(features, :number, :plural)
      else
        Map.put(features, :number, :singular)
      end

    features
  end

  ## Irregular Forms Dictionaries

  defp irregular_verbs do
    %{
      # ser (to be)
      "sóc" => "ser",
      "ets" => "ser",
      "és" => "ser",
      "som" => "ser",
      "sou" => "ser",
      "són" => "ser",
      "era" => "ser",
      "eres" => "ser",
      "érem" => "ser",
      "éreu" => "ser",
      "eren" => "ser",
      "fui" => "ser",
      "fou" => "ser",
      "fórem" => "ser",
      "fóreu" => "ser",
      "foren" => "ser",
      "essent" => "ser",
      # estar (to be)
      "estic" => "estar",
      "estàs" => "estar",
      "està" => "estar",
      "estem" => "estar",
      "esteu" => "estar",
      "estan" => "estar",
      "estava" => "estar",
      "estaves" => "estar",
      "estàvem" => "estar",
      "estàveu" => "estar",
      "estaven" => "estar",
      "estat" => "estar",
      "estant" => "estar",
      # haver (to have)
      "he" => "haver",
      "has" => "haver",
      "ha" => "haver",
      "hem" => "haver",
      "heu" => "haver",
      "han" => "haver",
      "havia" => "haver",
      "havies" => "haver",
      "havíem" => "haver",
      "havíeu" => "haver",
      "havien" => "haver",
      "hagut" => "haver",
      "havent" => "haver",
      # anar (to go)
      "vaig" => "anar",
      "vas" => "anar",
      "va" => "anar",
      "anem" => "anar",
      "aneu" => "anar",
      "van" => "anar",
      "anava" => "anar",
      # fer (to do/make)
      "faig" => "fer",
      "fas" => "fer",
      "fa" => "fer",
      "fem" => "fer",
      "feu" => "fer",
      "fan" => "fer",
      "fet" => "fer",
      "fent" => "fer",
      # dir (to say)
      "dic" => "dir",
      "dius" => "dir",
      "diu" => "dir",
      "diem" => "dir",
      "dieu" => "dir",
      "diuen" => "dir",
      "dit" => "dir",
      "dient" => "dir",
      # poder (can)
      "puc" => "poder",
      "pots" => "poder",
      "pot" => "poder",
      "podem" => "poder",
      "podeu" => "poder",
      "poden" => "poder",
      "pogut" => "poder",
      "podent" => "poder",
      # voler (to want)
      "vull" => "voler",
      "vols" => "voler",
      "vol" => "voler",
      "volem" => "voler",
      "voleu" => "voler",
      "volen" => "voler",
      "volgut" => "voler",
      "volent" => "voler",
      # veure (to see)
      "veig" => "veure",
      "veus" => "veure",
      "veu" => "veure",
      "veiem" => "veure",
      "veieu" => "veure",
      "veuen" => "veure",
      "vist" => "veure",
      "veient" => "veure",
      # tenir (to have)
      "tinc" => "tenir",
      "tens" => "tenir",
      "té" => "tenir",
      "tenim" => "tenir",
      "teniu" => "tenir",
      "tenen" => "tenir",
      "tingut" => "tenir",
      "tenint" => "tenir",
      # venir (to come)
      "vinc" => "venir",
      "véns" => "venir",
      "ve" => "venir",
      "venim" => "venir",
      "veniu" => "venir",
      "vénen" => "venir",
      "vingut" => "venir",
      "venint" => "venir"
    }
  end

  defp irregular_nouns do
    %{
      # Few irregular plurals in Catalan
    }
  end

  defp irregular_adjectives do
    %{
      "millor" => "bo",
      "millors" => "bo",
      "pitjor" => "dolent",
      "pitjors" => "dolent"
    }
  end
end
