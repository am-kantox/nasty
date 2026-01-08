defmodule Nasty.Language.Spanish.Morphology do
  @moduledoc """
  Morphological analyzer for Spanish tokens.

  Provides lemmatization (finding the base form of words) using:
  - Dictionary lookup for irregular forms
  - Rule-based suffix removal for regular conjugations/declensions

  ## Spanish-Specific Features

  - Verb lemmatization: all conjugations → infinitive (-ar, -er, -ir)
  - Noun lemmatization: plural → singular, gender variations
  - Adjective lemmatization: gender/number agreement
  - Morphological features: gender, number, tense, mood, person

  ## Examples

      iex> alias Nasty.Language.Spanish.{Tokenizer, POSTagger, Morphology}
      iex> {:ok, tokens} = Tokenizer.tokenize("hablando")
      iex> {:ok, tagged} = POSTagger.tag_pos(tokens)
      iex> {:ok, analyzed} = Morphology.analyze(tagged)
      iex> hd(analyzed).lemma
      "hablar"
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
  Lemmatizes a Spanish word based on its part-of-speech tag.

  Returns the base form (lemma) of a word using dictionary lookup for irregular
  forms and rule-based suffix removal for regular forms.

  ## Parameters

    - `word` - The word to lemmatize (lowercase string)
    - `pos_tag` - Part-of-speech tag atom (`:verb`, `:noun`, `:adj`, etc.)

  ## Returns

    - `String.t()` - The lemmatized form of the word

  ## Examples

      iex> Nasty.Language.Spanish.Morphology.lemmatize("hablando", :verb)
      "hablar"

      iex> Nasty.Language.Spanish.Morphology.lemmatize("casas", :noun)
      "casa"

      iex> Nasty.Language.Spanish.Morphology.lemmatize("buena", :adj)
      "bueno"
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

  # Rule-based lemmatization for Spanish verbs
  # credo:disable-for-lines:161
  defp rule_based_lemma(word, :verb) do
    case String.reverse(word) do
      # Gerund: -ando, -iendo → -ar, -er/-ir
      "odna" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "odnei" <> rest ->
        # Could be -er or -ir, default to -er
        rest |> String.reverse() |> Kernel.<>("er")

      # Past participle: -ado → -ar, -ido → -er/-ir
      "oda" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "odi" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("er")

      # Present tense -ar verbs
      <<"o", rest::binary>> when byte_size(rest) >= 1 ->
        # hablo → hablar
        rest |> String.reverse() |> Kernel.<>("ar")

      "sa" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      <<"a", rest::binary>> when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "soma" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "siá" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "na" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      # Present tense -er verbs
      "se" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      <<"e", rest::binary>> when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("er")

      "some" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "sié" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "ne" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      # Present tense -ir verbs
      "somi" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ir")

      "sí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ir")

      # Preterite tense
      <<"é", rest::binary>> ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "etsa" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      <<"ó", rest::binary>> ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "sietsa" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "nora" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      <<"í", rest::binary>> when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("ir")

      "etsi" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "oí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ir")

      "sietsi" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "norei" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      # Imperfect tense
      "aba" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "saba" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "somabá" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "siaba" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "naba" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "aí" <> rest when byte_size(rest) >= 1 ->
        rest |> String.reverse() |> Kernel.<>("er")

      "saí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "somaí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "siaí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      "naí" <> rest ->
        rest |> String.reverse() |> Kernel.<>("er")

      # Future tense
      "ér" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "sár" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "ár" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "somer" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "siér" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "nár" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      # Conditional
      "aír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "saír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "somaír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "siaír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      "naír" <> rest ->
        rest |> String.reverse() |> Kernel.<>("ar")

      _ ->
        word
    end
  end

  # Rule-based lemmatization for Spanish nouns
  defp rule_based_lemma(word, :noun) do
    cond do
      # Plural ending in -es
      String.ends_with?(word, "iones") ->
        # naciones → nación
        String.slice(word, 0..-4//1)

      String.ends_with?(word, "ces") ->
        # luces → luz
        String.slice(word, 0..-4//1) <> "z"

      String.ends_with?(word, "es") and String.length(word) > 3 ->
        # casas → casa, but keep final consonant
        base = String.slice(word, 0..-3//1)

        if String.ends_with?(base, ["z"]) do
          base <> "z"
        else
          base
        end

      # Plural ending in -s
      String.ends_with?(word, "s") and String.length(word) > 2 ->
        # casas → casa
        String.slice(word, 0..-2//1)

      true ->
        word
    end
  end

  # Rule-based lemmatization for Spanish adjectives
  defp rule_based_lemma(word, :adj) do
    cond do
      # Feminine singular: -a → -o
      String.ends_with?(word, "a") and String.length(word) > 2 ->
        String.slice(word, 0..-2//1) <> "o"

      # Feminine plural: -as → -o
      String.ends_with?(word, "as") ->
        String.slice(word, 0..-3//1) <> "o"

      # Masculine plural: -os → -o
      String.ends_with?(word, "os") ->
        String.slice(word, 0..-3//1) <> "o"

      # Plural -es → remove -es
      String.ends_with?(word, "es") and String.length(word) > 3 ->
        String.slice(word, 0..-3//1)

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
      # Gerund
      String.ends_with?(word, "ando") or String.ends_with?(word, "iendo") ->
        %{tense: :present, aspect: :progressive, mood: :indicative}

      # Past participle
      String.ends_with?(word, "ado") or String.ends_with?(word, "ido") ->
        %{tense: :past, aspect: :perfective}

      # Preterite
      String.ends_with?(word, ["é", "ó", "aste", "iste", "asteis", "isteis", "aron", "ieron"]) ->
        %{tense: :past, mood: :indicative}

      # Imperfect
      String.ends_with?(word, [
        "aba",
        "abas",
        "ábamos",
        "abais",
        "aban",
        "ía",
        "ías",
        "íamos",
        "íais",
        "ían"
      ]) ->
        %{tense: :imperfect, mood: :indicative}

      # Future
      String.ends_with?(word, ["ré", "rás", "rá", "remos", "réis", "rán"]) ->
        %{tense: :future, mood: :indicative}

      # Conditional
      String.ends_with?(word, ["ría", "rías", "ríamos", "ríais", "rían"]) ->
        %{tense: :conditional, mood: :conditional}

      # Present tense (default)
      true ->
        %{tense: :present, mood: :indicative}
    end
  end

  defp extract_noun_features(word, lemma) do
    features = %{}

    # Gender (heuristic based on ending)
    features =
      cond do
        String.ends_with?(word, "o") or String.ends_with?(word, "os") ->
          Map.put(features, :gender, :masculine)

        String.ends_with?(word, "a") or String.ends_with?(word, "as") ->
          Map.put(features, :gender, :feminine)

        true ->
          features
      end

    # Number
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

    # Gender
    features =
      cond do
        String.ends_with?(word, "o") or String.ends_with?(word, "os") ->
          Map.put(features, :gender, :masculine)

        String.ends_with?(word, "a") or String.ends_with?(word, "as") ->
          Map.put(features, :gender, :feminine)

        true ->
          features
      end

    # Number
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
      "soy" => "ser",
      "eres" => "ser",
      "es" => "ser",
      "somos" => "ser",
      "sois" => "ser",
      "son" => "ser",
      "era" => "ser",
      "eras" => "ser",
      "éramos" => "ser",
      "erais" => "ser",
      "eran" => "ser",
      "fui" => "ser",
      "fuiste" => "ser",
      "fue" => "ser",
      "fuimos" => "ser",
      "fuisteis" => "ser",
      "fueron" => "ser",
      "sido" => "ser",
      "siendo" => "ser",
      # estar (to be)
      "estoy" => "estar",
      "estás" => "estar",
      "está" => "estar",
      "estamos" => "estar",
      "estáis" => "estar",
      "están" => "estar",
      "estaba" => "estar",
      "estabas" => "estar",
      "estábamos" => "estar",
      "estabais" => "estar",
      "estaban" => "estar",
      "estuve" => "estar",
      "estuviste" => "estar",
      "estuvo" => "estar",
      "estuvimos" => "estar",
      "estuvisteis" => "estar",
      "estuvieron" => "estar",
      "estado" => "estar",
      "estando" => "estar",
      # haber (to have - auxiliary)
      "he" => "haber",
      "has" => "haber",
      "ha" => "haber",
      "hemos" => "haber",
      "habéis" => "haber",
      "han" => "haber",
      "había" => "haber",
      "habías" => "haber",
      "habíamos" => "haber",
      "habíais" => "haber",
      "habían" => "haber",
      "hube" => "haber",
      "hubiste" => "haber",
      "hubo" => "haber",
      "hubimos" => "haber",
      "hubisteis" => "haber",
      "hubieron" => "haber",
      "habido" => "haber",
      "habiendo" => "haber",
      # ir (to go)
      "voy" => "ir",
      "vas" => "ir",
      "va" => "ir",
      "vamos" => "ir",
      "vais" => "ir",
      "van" => "ir",
      "iba" => "ir",
      "ibas" => "ir",
      "íbamos" => "ir",
      "ibais" => "ir",
      "iban" => "ir",
      # hacer (to do/make)
      "hago" => "hacer",
      "haces" => "hacer",
      "hace" => "hacer",
      "hacemos" => "hacer",
      "hacéis" => "hacer",
      "hacen" => "hacer",
      "hice" => "hacer",
      "hiciste" => "hacer",
      "hizo" => "hacer",
      "hicimos" => "hacer",
      "hicisteis" => "hacer",
      "hicieron" => "hacer",
      "hecho" => "hacer",
      "haciendo" => "hacer",
      # tener (to have)
      "tengo" => "tener",
      "tienes" => "tener",
      "tiene" => "tener",
      "tenemos" => "tener",
      "tenéis" => "tener",
      "tienen" => "tener",
      "tuve" => "tener",
      "tuviste" => "tener",
      "tuvo" => "tener",
      "tuvimos" => "tener",
      "tuvisteis" => "tener",
      "tuvieron" => "tener",
      # decir (to say)
      "digo" => "decir",
      "dices" => "decir",
      "dice" => "decir",
      "decimos" => "decir",
      "decís" => "decir",
      "dicen" => "decir",
      "dije" => "decir",
      "dijiste" => "decir",
      "dijo" => "decir",
      "dijimos" => "decir",
      "dijisteis" => "decir",
      "dijeron" => "decir",
      "dicho" => "decir",
      "diciendo" => "decir",
      # poder (can)
      "puedo" => "poder",
      "puedes" => "poder",
      "puede" => "poder",
      "podemos" => "poder",
      "podéis" => "poder",
      "pueden" => "poder",
      "pude" => "poder",
      "pudiste" => "poder",
      "pudo" => "poder",
      "pudimos" => "poder",
      "pudisteis" => "poder",
      "pudieron" => "poder",
      "podido" => "poder",
      "pudiendo" => "poder",
      # poner (to put)
      "pongo" => "poner",
      "pones" => "poner",
      "pone" => "poner",
      "ponemos" => "poner",
      "ponéis" => "poner",
      "ponen" => "poner",
      "puse" => "poner",
      "pusiste" => "poner",
      "puso" => "poner",
      "pusimos" => "poner",
      "pusisteis" => "poner",
      "pusieron" => "poner",
      "puesto" => "poner",
      "poniendo" => "poner",
      # ver (to see)
      "veo" => "ver",
      "ves" => "ver",
      "ve" => "ver",
      "vemos" => "ver",
      "veis" => "ver",
      "ven" => "ver",
      "vi" => "ver",
      "viste" => "ver",
      "vio" => "ver",
      "vimos" => "ver",
      "visteis" => "ver",
      "vieron" => "ver",
      "visto" => "ver",
      "viendo" => "ver"
    }
  end

  defp irregular_nouns do
    %{
      # Very few irregular plurals in Spanish
      # Most follow regular patterns
    }
  end

  defp irregular_adjectives do
    %{
      # Comparatives and superlatives that don't follow regular patterns
      "mejor" => "bueno",
      "mejores" => "bueno",
      "peor" => "malo",
      "peores" => "malo",
      "mayor" => "grande",
      "mayores" => "grande",
      "menor" => "pequeño",
      "menores" => "pequeño"
    }
  end
end
