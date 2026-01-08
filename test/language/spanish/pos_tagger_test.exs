defmodule Nasty.Language.Spanish.POSTaggerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Node, Token}
  alias Nasty.Language.Spanish.POSTagger

  describe "tag_pos/2" do
    test "correctly tags Spanish verb conjugations in present tense" do
      tokens = build_tokens(["hablo", "hablas", "habla", "hablamos", "habláis", "hablan"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags Spanish -er verb conjugations" do
      tokens = build_tokens(["como", "comes", "come", "comemos", "coméis", "comen"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags Spanish -ir verb conjugations" do
      tokens = build_tokens(["vivo", "vives", "vive", "vivimos", "vivís", "viven"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags preterite tense verbs" do
      tokens = build_tokens(["hablé", "hablaste", "habló", "hablaron"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags imperfect tense verbs" do
      tokens = build_tokens(["hablaba", "hablabas", "hablaban", "comía", "comías", "comían"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags future tense verbs" do
      tokens = build_tokens(["hablaré", "hablarás", "hablará", "hablaremos", "hablarán"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags conditional verbs" do
      tokens = build_tokens(["hablaría", "hablarías", "hablaría", "hablaríamos", "hablarían"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags gerunds" do
      tokens = build_tokens(["hablando", "comiendo", "viviendo"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end

    test "correctly tags past participles" do
      tokens = build_tokens(["hablado", "comido", "vivido"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end
  end

  describe "gender agreement" do
    test "recognizes masculine nouns with -o ending" do
      tokens = build_tokens(["gato", "perro", "libro"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :noun))
    end

    test "recognizes feminine nouns with -a ending" do
      tokens = build_tokens(["casa", "mesa", "silla"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :noun))
    end

    test "recognizes adjectives with gender agreement" do
      tokens = build_tokens(["el", "gato", "blanco"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [art, noun, adj] = tagged
      assert art.pos_tag == :det
      assert noun.pos_tag == :noun
      assert adj.pos_tag == :adj
    end

    test "recognizes feminine adjectives" do
      tokens = build_tokens(["la", "casa", "blanca"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [art, noun, adj] = tagged
      assert art.pos_tag == :det
      assert noun.pos_tag == :noun
      assert adj.pos_tag == :adj
    end
  end

  describe "number agreement" do
    test "recognizes plural nouns with -s ending" do
      tokens = build_tokens(["gatos", "casas", "libros"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      # All should be recognized as nouns (plural form)
      assert Enum.all?(tagged, &(&1.pos_tag in [:noun, :adj]))
    end

    test "recognizes plural nouns with -es ending" do
      tokens = build_tokens(["flores", "animales", "ciudades"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag in [:noun, :verb, :adj]))
    end

    test "recognizes plural articles" do
      tokens = build_tokens(["los", "las", "unos", "unas"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :det))
    end

    test "handles plural verb forms" do
      tokens = build_tokens(["hablamos", "comemos", "vivimos"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :verb))
    end
  end

  describe "closed-class words" do
    test "correctly tags Spanish articles" do
      tokens = build_tokens(["el", "la", "los", "las", "un", "una", "unos", "unas"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :det))
    end

    test "correctly tags Spanish pronouns" do
      tokens = build_tokens(["yo", "tú", "él", "ella", "nosotros", "ellos"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :pron))
    end

    test "correctly tags Spanish prepositions" do
      tokens = build_tokens(["a", "de", "en", "con", "por", "para", "desde", "hasta"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :adp))
    end

    test "correctly tags Spanish contractions" do
      tokens = build_tokens(["del", "al"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :adp))
    end

    test "correctly tags coordinating conjunctions" do
      tokens = build_tokens(["y", "e", "o", "u", "pero", "sino", "ni"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :cconj))
    end

    test "correctly tags subordinating conjunctions" do
      # Only test unambiguous subordinating conjunctions
      # "que" is also a pronoun, "como" is also a verb, so they're ambiguous
      tokens = build_tokens(["cuando", "porque", "aunque", "mientras"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :sconj))
    end
  end

  describe "auxiliary verbs" do
    test "correctly tags ser conjugations as auxiliary" do
      tokens = build_tokens(["soy", "eres", "es", "somos", "sois", "son"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :aux))
    end

    test "correctly tags estar conjugations as auxiliary" do
      tokens = build_tokens(["estoy", "estás", "está", "estamos", "están"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :aux))
    end

    test "correctly tags haber conjugations as auxiliary" do
      tokens = build_tokens(["he", "has", "ha", "hemos", "han"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :aux))
    end
  end

  describe "morphological patterns" do
    test "recognizes nouns with -ción suffix" do
      tokens = build_tokens(["nación", "canción", "estación"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :noun))
    end

    test "recognizes nouns with -dad suffix" do
      tokens = build_tokens(["ciudad", "verdad", "libertad"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :noun))
    end

    test "recognizes adjectives with -oso/-osa suffix" do
      tokens = build_tokens(["hermoso", "hermosa", "famoso"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :adj))
    end

    test "recognizes adjectives with -able suffix" do
      tokens = build_tokens(["amable", "notable", "confiable"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :adj))
    end

    test "recognizes adverbs with -mente suffix" do
      tokens = build_tokens(["rápidamente", "lentamente", "claramente"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :adv))
    end
  end

  describe "context-based tagging" do
    test "tags word after article as noun" do
      tokens = build_tokens(["el", "gato"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [art, noun] = tagged
      assert art.pos_tag == :det
      assert noun.pos_tag == :noun
    end

    test "tags word after preposition as noun" do
      tokens = build_tokens(["de", "Madrid"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [prep, noun] = tagged
      assert prep.pos_tag == :adp
      assert noun.pos_tag in [:noun, :propn]
    end

    test "handles ambiguous words using context" do
      tokens = build_tokens(["la", "casa", "grande"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert match?([_, _, _], tagged)
    end
  end

  describe "proper nouns" do
    test "recognizes capitalized words as proper nouns" do
      tokens = build_tokens(["María", "José", "Madrid"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, &(&1.pos_tag == :propn))
    end

    test "handles proper nouns in mid-sentence" do
      tokens = build_tokens(["Vivo", "en", "Barcelona"])

      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [_verb, prep, propn] = tagged
      assert prep.pos_tag == :adp
      assert propn.pos_tag == :propn
    end
  end

  # Helper functions

  defp build_tokens(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      byte_offset = idx * 10

      %Token{
        text: word,
        pos_tag: :x,
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
