defmodule Nasty.Language.Catalan.POSTaggerTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.Catalan.{Tokenizer, POSTagger}

  describe "tag_pos/1 - basic tagging" do
    test "tags simple sentence" do
      {:ok, tokens} = Tokenizer.tokenize("El gat dorm.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert match?([_, _, _, _], tagged)
      [el, gat, dorm, punct] = tagged

      assert el.pos_tag == :det
      assert gat.pos_tag == :noun
      assert dorm.pos_tag == :verb
      assert punct.pos_tag == :punct
    end

    test "tags articles" do
      {:ok, tokens} = Tokenizer.tokenize("el la els les")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :det end)
    end

    test "tags pronouns" do
      {:ok, tokens} = Tokenizer.tokenize("jo tu ell nosaltres")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :pron end)
    end

    test "tags prepositions" do
      {:ok, tokens} = Tokenizer.tokenize("a de amb per")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :adp end)
    end

    test "tags coordinating conjunctions" do
      {:ok, tokens} = Tokenizer.tokenize("i o però")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :cconj end)
    end
  end

  describe "tag_pos/1 - verbs" do
    test "tags common verbs" do
      {:ok, tokens} = Tokenizer.tokenize("anar fer dir")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :verb end)
    end

    test "tags verb conjugations" do
      {:ok, tokens} = Tokenizer.tokenize("parlo parles parla")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :verb end)
    end

    test "tags auxiliary verbs" do
      {:ok, tokens} = Tokenizer.tokenize("ser estar haver")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :aux end)
    end

    test "tags gerunds" do
      {:ok, tokens} = Tokenizer.tokenize("parlant menjant")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :verb end)
    end
  end

  describe "tag_pos/1 - nouns and adjectives" do
    test "tags common nouns" do
      {:ok, tokens} = Tokenizer.tokenize("casa gat dia")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :noun end)
    end

    test "tags common adjectives" do
      {:ok, tokens} = Tokenizer.tokenize("bo gran petit")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :adj end)
    end

    test "tags noun after article" do
      {:ok, tokens} = Tokenizer.tokenize("la casa")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [la, casa] = tagged
      assert la.pos_tag == :det
      assert casa.pos_tag == :noun
    end

    test "tags adjective after noun" do
      {:ok, tokens} = Tokenizer.tokenize("El gat negre")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [_el, gat, _negre] = tagged
      assert gat.pos_tag == :noun
    end
  end

  describe "tag_pos/1 - Catalan-specific features" do
    test "tags contractions" do
      {:ok, tokens} = Tokenizer.tokenize("del al pel")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert Enum.all?(tagged, fn t -> t.pos_tag == :adp end)
    end

    test "tags apostrophe contractions" do
      {:ok, tokens} = Tokenizer.tokenize("L'home d'or")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [l, home, d, gold] = tagged
      assert l.pos_tag == :det
      assert home.pos_tag == :noun
      assert d.pos_tag == :adp
      assert gold.pos_tag == :noun
    end

    test "handles interpunct words" do
      {:ok, tokens} = Tokenizer.tokenize("Col·laborar és important.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      texts = Enum.map(tagged, & &1.text)
      assert "Col·laborar" in texts

      collaborar = Enum.find(tagged, &(&1.text == "Col·laborar"))
      assert collaborar.pos_tag == :verb
    end

    test "tags Catalan diacritics" do
      {:ok, tokens} = Tokenizer.tokenize("És això açò")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      [es, aixo, aco] = tagged
      assert es.pos_tag == :aux
      assert aixo.pos_tag == :pron
      assert aco.pos_tag == :pron
    end
  end

  describe "tag_pos/1 - numbers and punctuation" do
    test "preserves number tags" do
      {:ok, tokens} = Tokenizer.tokenize("Hi ha 10 gats")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      num_token = Enum.find(tagged, &(&1.text == "10"))
      assert num_token.pos_tag == :num
    end

    test "preserves punctuation tags" do
      {:ok, tokens} = Tokenizer.tokenize("Hola, món!")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      punct_tokens = Enum.filter(tagged, &(&1.pos_tag == :punct))
      assert match?([_, _], punct_tokens)
    end
  end

  describe "tag_pos/1 - complex sentences" do
    test "tags sentence with multiple features" do
      {:ok, tokens} = Tokenizer.tokenize("L'home va del mercat al parc.")
      {:ok, tagged} = POSTagger.tag_pos(tokens)

      assert match?([_, _, _, _, _, _, _, _], tagged)

      # Check that each token has a tag
      assert Enum.all?(tagged, fn t -> t.pos_tag != nil end)
    end
  end
end
