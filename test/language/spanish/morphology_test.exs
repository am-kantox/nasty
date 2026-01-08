defmodule Nasty.Language.Spanish.MorphologyTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.Spanish.Morphology

  describe "lemmatize/2" do
    test "lemmatizes Spanish regular -ar verbs to infinitive" do
      assert Morphology.lemmatize("hablo", :verb) == "hablar"
      assert Morphology.lemmatize("hablas", :verb) == "hablar"
      assert Morphology.lemmatize("habla", :verb) == "hablar"
      assert Morphology.lemmatize("hablamos", :verb) == "hablar"
      assert Morphology.lemmatize("hablan", :verb) == "hablar"
    end

    test "lemmatizes Spanish regular -er verbs to infinitive" do
      assert Morphology.lemmatize("como", :verb) == "comer"
      assert Morphology.lemmatize("comes", :verb) == "comer"
      assert Morphology.lemmatize("come", :verb) == "comer"
      assert Morphology.lemmatize("comemos", :verb) == "comer"
      assert Morphology.lemmatize("comen", :verb) == "comer"
    end

    test "lemmatizes Spanish regular -ir verbs to infinitive" do
      assert Morphology.lemmatize("vivo", :verb) == "vivir"
      assert Morphology.lemmatize("vives", :verb) == "vivir"
      assert Morphology.lemmatize("vive", :verb) == "vivir"
      assert Morphology.lemmatize("vivimos", :verb) == "vivir"
      assert Morphology.lemmatize("viven", :verb) == "vivir"
    end

    test "lemmatizes Spanish gerunds to infinitive" do
      assert Morphology.lemmatize("hablando", :verb) == "hablar"
      assert Morphology.lemmatize("comiendo", :verb) == "comer"
      assert Morphology.lemmatize("viviendo", :verb) == "vivir"
    end

    test "lemmatizes Spanish past participles to infinitive" do
      assert Morphology.lemmatize("hablado", :verb) == "hablar"
      assert Morphology.lemmatize("comido", :verb) == "comer"
      assert Morphology.lemmatize("vivido", :verb) == "vivir"
    end

    test "lemmatizes irregular Spanish verbs" do
      assert Morphology.lemmatize("soy", :verb) == "ser"
      assert Morphology.lemmatize("es", :verb) == "ser"
      assert Morphology.lemmatize("fue", :verb) == "ser"
      assert Morphology.lemmatize("estoy", :verb) == "estar"
      assert Morphology.lemmatize("está", :verb) == "estar"
    end

    test "lemmatizes plural nouns to singular" do
      assert Morphology.lemmatize("gatos", :noun) == "gato"
      assert Morphology.lemmatize("casas", :noun) == "casa"
      assert Morphology.lemmatize("flores", :noun) == "flor"
      assert Morphology.lemmatize("animales", :noun) == "animal"
    end

    test "lemmatizes feminine adjectives to masculine" do
      assert Morphology.lemmatize("buena", :adj) == "bueno"
      assert Morphology.lemmatize("blanca", :adj) == "blanco"
      assert Morphology.lemmatize("pequeña", :adj) == "pequeño"
    end

    test "lemmatizes plural adjectives to singular masculine" do
      assert Morphology.lemmatize("buenos", :adj) == "bueno"
      assert Morphology.lemmatize("buenas", :adj) == "bueno"
      assert Morphology.lemmatize("blancos", :adj) == "blanco"
    end

    test "handles irregular comparatives and superlatives" do
      assert Morphology.lemmatize("mejor", :adj) == "bueno"
      assert Morphology.lemmatize("peor", :adj) == "malo"
      assert Morphology.lemmatize("mayor", :adj) == "grande"
      assert Morphology.lemmatize("menor", :adj) == "pequeño"
    end
  end

  describe "analyze/1" do
    test "adds lemmas to all tokens" do
      tokens =
        build_tagged_tokens([
          {"hablo", :verb},
          {"casas", :noun},
          {"buenas", :adj}
        ])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert match?([_, _, _], analyzed)
      assert Enum.all?(analyzed, &(&1.lemma != nil))

      [verb, noun, adj] = analyzed
      assert verb.lemma == "hablar"
      assert noun.lemma == "casa"
      assert adj.lemma == "bueno"
    end

    test "extracts verb morphological features" do
      tokens = build_tagged_tokens([{"hablando", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [verb] = analyzed
      assert verb.morphology.tense == :present
      assert verb.morphology.aspect == :progressive
    end

    test "extracts noun gender features" do
      tokens = build_tagged_tokens([{"gato", :noun}, {"casa", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [masc, fem] = analyzed
      assert masc.morphology.gender == :masculine
      assert fem.morphology.gender == :feminine
    end

    test "extracts noun number features" do
      tokens = build_tagged_tokens([{"gato", :noun}, {"gatos", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [sing, plur] = analyzed
      assert sing.morphology.number == :singular
      assert plur.morphology.number == :plural
    end

    test "extracts adjective gender and number features" do
      tokens =
        build_tagged_tokens([
          {"bueno", :adj},
          {"buena", :adj},
          {"buenos", :adj},
          {"buenas", :adj}
        ])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [masc_sing, fem_sing, masc_plur, fem_plur] = analyzed

      assert masc_sing.morphology.gender == :masculine
      assert masc_sing.morphology.number == :singular

      assert fem_sing.morphology.gender == :feminine
      assert fem_sing.morphology.number == :singular

      assert masc_plur.morphology.gender == :masculine
      assert masc_plur.morphology.number == :plural

      assert fem_plur.morphology.gender == :feminine
      assert fem_plur.morphology.number == :plural
    end

    test "identifies preterite tense" do
      tokens = build_tagged_tokens([{"hablé", :verb}, {"comí", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.tense == :past))
    end

    test "identifies imperfect tense" do
      tokens = build_tagged_tokens([{"hablaba", :verb}, {"comía", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.tense == :imperfect))
    end

    test "identifies future tense" do
      tokens = build_tagged_tokens([{"hablaré", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [verb] = analyzed
      assert verb.morphology.tense == :future
    end

    test "identifies conditional mood" do
      tokens = build_tagged_tokens([{"hablaría", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [verb] = analyzed
      assert verb.morphology.tense == :conditional
    end

    test "skips morphology for punctuation" do
      tokens = build_tagged_tokens([{".", :punct}, {",", :punct}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, fn token ->
               token.lemma == token.text
             end)
    end

    test "skips morphology for numbers" do
      tokens = build_tagged_tokens([{"25", :num}, {"100", :num}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, fn token ->
               token.lemma == token.text
             end)
    end
  end

  describe "gender agreement analysis" do
    test "correctly identifies masculine gender from -o ending" do
      tokens = build_tagged_tokens([{"libro", :noun}, {"gato", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.gender == :masculine))
    end

    test "correctly identifies feminine gender from -a ending" do
      tokens = build_tagged_tokens([{"casa", :noun}, {"mesa", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.gender == :feminine))
    end

    test "handles gender-neutral words" do
      tokens = build_tagged_tokens([{"estudiante", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [noun] = analyzed
      # Gender-neutral nouns might not have gender marked
      assert is_map(noun.morphology)
    end
  end

  describe "number agreement analysis" do
    test "correctly identifies singular number" do
      tokens = build_tagged_tokens([{"gato", :noun}, {"libro", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.number == :singular))
    end

    test "correctly identifies plural from -s" do
      tokens = build_tagged_tokens([{"gatos", :noun}, {"libros", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.number == :plural))
    end

    test "correctly identifies plural from -es" do
      tokens = build_tagged_tokens([{"flores", :noun}, {"animales", :noun}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      assert Enum.all?(analyzed, &(&1.morphology.number == :plural))
    end
  end

  describe "verb feature extraction" do
    test "identifies perfective aspect for past participles" do
      tokens = build_tagged_tokens([{"hablado", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [verb] = analyzed
      assert verb.morphology.aspect == :perfective
    end

    test "identifies progressive aspect for gerunds" do
      tokens = build_tagged_tokens([{"hablando", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [verb] = analyzed
      assert verb.morphology.aspect == :progressive
    end

    test "identifies indicative mood for regular conjugations" do
      tokens = build_tagged_tokens([{"hablo", :verb}])

      {:ok, analyzed} = Morphology.analyze(tokens)

      [verb] = analyzed
      assert verb.morphology.mood == :indicative
    end
  end

  # Helper functions

  defp build_tagged_tokens(word_pos_pairs) do
    word_pos_pairs
    |> Enum.with_index()
    |> Enum.map(fn {{word, pos}, idx} ->
      byte_offset = idx * 10

      %Token{
        text: word,
        pos_tag: pos,
        lemma: nil,
        language: :es,
        span:
          Node.make_span(
            {1, idx * 10},
            byte_offset,
            {1, idx * 10 + String.length(word)},
            byte_offset + byte_size(word)
          ),
        morphology: %{}
      }
    end)
  end
end
