defmodule Nasty.Language.Catalan.TokenizerTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.Token
  alias Nasty.Language.Catalan.Tokenizer

  describe "tokenize/1 - basic functionality" do
    test "tokenizes simple Catalan sentence" do
      {:ok, tokens} = Tokenizer.tokenize("El gat dorm.")

      assert match?([_, _, _, _], tokens)
      assert Enum.map(tokens, & &1.text) == ["El", "gat", "dorm", "."]
      assert Enum.all?(tokens, fn t -> t.language == :ca end)
    end

    test "handles empty string" do
      {:ok, tokens} = Tokenizer.tokenize("")
      assert tokens == []
    end

    test "handles whitespace-only text" do
      {:ok, tokens} = Tokenizer.tokenize("   \n\t  ")
      assert tokens == []
    end

    test "handles multiple sentences" do
      {:ok, tokens} = Tokenizer.tokenize("Hola. Com estàs? Bé!")

      texts = Enum.map(tokens, & &1.text)
      assert "." in texts
      assert "?" in texts
      assert "!" in texts
    end
  end

  describe "tokenize/1 - interpunct (l·l)" do
    test "keeps interpunct words as single token" do
      {:ok, tokens} = Tokenizer.tokenize("Col·laborar és important.")

      texts = Enum.map(tokens, & &1.text)
      assert "Col·laborar" in texts
      refute "Col" in texts
      refute "laborar" in texts
    end

    test "handles multiple interpunct words" do
      {:ok, tokens} = Tokenizer.tokenize("La intel·ligència col·labora.")

      texts = Enum.map(tokens, & &1.text)
      assert "intel·ligència" in texts
      assert "col·labora" in texts
    end

    test "handles interpunct with uppercase" do
      {:ok, tokens} = Tokenizer.tokenize("Il·lusió.")

      texts = Enum.map(tokens, & &1.text)
      assert "Il·lusió" in texts
    end

    test "handles interpunct in middle of sentence" do
      {:ok, tokens} = Tokenizer.tokenize("Vull col·laborar avui.")

      assert match?([_, _, _, _], tokens)
      texts = Enum.map(tokens, & &1.text)
      assert "col·laborar" in texts
    end
  end

  describe "tokenize/1 - apostrophe contractions" do
    test "tokenizes l' as separate token" do
      {:ok, tokens} = Tokenizer.tokenize("L'home arriba.")

      texts = Enum.map(tokens, & &1.text)
      assert "L'" in texts
      assert "home" in texts
      assert length(texts) == 4
    end

    test "tokenizes d' as separate token" do
      {:ok, tokens} = Tokenizer.tokenize("L'anell d'or.")

      texts = Enum.map(tokens, & &1.text)
      assert "L'" in texts
      assert "d'" in texts
      assert "or" in texts
    end

    test "handles s' contraction" do
      {:ok, tokens} = Tokenizer.tokenize("S'ha anat.")

      texts = Enum.map(tokens, & &1.text)
      assert "S'" in texts
      assert "ha" in texts
    end

    test "handles n', m', t' contractions" do
      {:ok, tokens} = Tokenizer.tokenize("N'hi ha.")
      texts1 = Enum.map(tokens, & &1.text)
      assert "N'" in texts1

      {:ok, tokens} = Tokenizer.tokenize("M'agrada.")
      texts2 = Enum.map(tokens, & &1.text)
      assert "M'" in texts2

      {:ok, tokens} = Tokenizer.tokenize("T'estimo.")
      texts3 = Enum.map(tokens, & &1.text)
      assert "T'" in texts3
    end

    test "handles lowercase apostrophe contractions" do
      {:ok, tokens} = Tokenizer.tokenize("l'home d'or s'ha anat.")

      texts = Enum.map(tokens, & &1.text)
      assert "l'" in texts
      assert "d'" in texts
      assert "s'" in texts
    end

    test "apostrophe must be followed by word" do
      {:ok, tokens} = Tokenizer.tokenize("L'home.")

      texts = Enum.map(tokens, & &1.text)
      assert "L'" in texts
      assert "home" in texts
    end
  end

  describe "tokenize/1 - article contractions" do
    test "recognizes del contraction" do
      {:ok, tokens} = Tokenizer.tokenize("Vinc del mercat.")

      texts = Enum.map(tokens, & &1.text)
      assert "del" in texts
    end

    test "recognizes al contraction" do
      {:ok, tokens} = Tokenizer.tokenize("Vaig al parc.")

      texts = Enum.map(tokens, & &1.text)
      assert "al" in texts
    end

    test "recognizes pel contraction" do
      {:ok, tokens} = Tokenizer.tokenize("Passa pel carrer.")

      texts = Enum.map(tokens, & &1.text)
      assert "pel" in texts
    end

    test "handles multiple contractions in sentence" do
      {:ok, tokens} = Tokenizer.tokenize("Vaig del poble al mercat.")

      texts = Enum.map(tokens, & &1.text)
      assert "del" in texts
      assert "al" in texts
    end

    test "contractions with uppercase" do
      {:ok, tokens} = Tokenizer.tokenize("Del poble. Al mercat.")

      texts = Enum.map(tokens, & &1.text)
      assert "Del" in texts
      assert "Al" in texts
    end

    test "does not match contraction as part of longer word" do
      {:ok, tokens} = Tokenizer.tokenize("Delia i Albert.")

      texts = Enum.map(tokens, & &1.text)
      assert "Delia" in texts
      assert "Albert" in texts
      refute "del" in texts
      refute "al" in texts
    end
  end

  describe "tokenize/1 - Catalan diacritics" do
    test "handles à vowel" do
      {:ok, tokens} = Tokenizer.tokenize("Està bé.")

      texts = Enum.map(tokens, & &1.text)
      assert "Està" in texts
    end

    test "handles è and é vowels" do
      {:ok, tokens} = Tokenizer.tokenize("És el cafè més bo.")

      texts = Enum.map(tokens, & &1.text)
      assert "És" in texts
      assert "cafè" in texts
      assert "més" in texts
    end

    test "handles í and ï vowels" do
      {:ok, tokens} = Tokenizer.tokenize("Així mateix.")

      texts = Enum.map(tokens, & &1.text)
      assert "Així" in texts
    end

    test "handles ò and ó vowels" do
      {:ok, tokens} = Tokenizer.tokenize("Això i allò.")

      texts = Enum.map(tokens, & &1.text)
      assert "Això" in texts
      assert "allò" in texts
    end

    test "handles ú and ü vowels" do
      {:ok, tokens} = Tokenizer.tokenize("Algú pregunta.")

      texts = Enum.map(tokens, & &1.text)
      assert "Algú" in texts
    end

    test "handles ç (ce trencada)" do
      {:ok, tokens} = Tokenizer.tokenize("Açò és això.")

      texts = Enum.map(tokens, & &1.text)
      assert "Açò" in texts
    end

    test "handles multiple diacritics in same sentence" do
      {:ok, tokens} = Tokenizer.tokenize("És això allò açò.")

      texts = Enum.map(tokens, & &1.text)
      assert "És" in texts
      assert "això" in texts
      assert "allò" in texts
      assert "açò" in texts
    end

    test "handles uppercase diacritics" do
      {:ok, tokens} = Tokenizer.tokenize("Àlex Òscar Éric.")

      texts = Enum.map(tokens, & &1.text)
      assert "Àlex" in texts
      assert "Òscar" in texts
      assert "Éric" in texts
    end
  end

  describe "tokenize/1 - punctuation" do
    test "handles sentence-ending punctuation" do
      {:ok, tokens} = Tokenizer.tokenize("Hola. Com estàs? Bé!")

      texts = Enum.map(tokens, & &1.text)
      assert "." in texts
      assert "?" in texts
      assert "!" in texts
    end

    test "handles comma" do
      {:ok, tokens} = Tokenizer.tokenize("Un, dos, tres.")

      texts = Enum.map(tokens, & &1.text)
      assert Enum.count(texts, &(&1 == ",")) == 2
    end

    test "handles colon and semicolon" do
      {:ok, tokens} = Tokenizer.tokenize("Primer: un; segon: dos.")

      texts = Enum.map(tokens, & &1.text)
      assert ":" in texts
      assert ";" in texts
    end

    test "handles parentheses" do
      {:ok, tokens} = Tokenizer.tokenize("El gat (negre) dorm.")

      texts = Enum.map(tokens, & &1.text)
      assert "(" in texts
      assert ")" in texts
    end

    test "punctuation tokens have :punct POS tag" do
      {:ok, tokens} = Tokenizer.tokenize("Hola.")

      punct_token = Enum.find(tokens, &(&1.text == "."))
      assert punct_token.pos_tag == :punct
    end
  end

  describe "tokenize/1 - numbers" do
    test "tokenizes integers" do
      {:ok, tokens} = Tokenizer.tokenize("Hi ha 25 gats.")

      texts = Enum.map(tokens, & &1.text)
      assert "25" in texts
    end

    test "tokenizes decimals with comma" do
      {:ok, tokens} = Tokenizer.tokenize("Pesa 3,5 kg.")

      texts = Enum.map(tokens, & &1.text)
      assert "3,5" in texts
    end

    test "tokenizes decimals with period" do
      {:ok, tokens} = Tokenizer.tokenize("Pesa 3.5 kg.")

      texts = Enum.map(tokens, & &1.text)
      assert "3.5" in texts
    end

    test "number tokens have :num POS tag" do
      {:ok, tokens} = Tokenizer.tokenize("Hi ha 10 gats.")

      num_token = Enum.find(tokens, &(&1.text == "10"))
      assert num_token.pos_tag == :num
    end
  end

  describe "tokenize/1 - position tracking" do
    test "first token starts at line 1, column 0" do
      {:ok, tokens} = Tokenizer.tokenize("Hola món")

      [first | _] = tokens
      assert elem(first.span.start_pos, 0) == 1
      assert elem(first.span.start_pos, 1) == 0
    end

    test "tracks column positions correctly" do
      {:ok, tokens} = Tokenizer.tokenize("El gat")

      [first, second] = tokens
      # "El" starts at column 0
      assert elem(first.span.start_pos, 1) == 0
      # "gat" starts at column 2 (after "El")
      assert elem(second.span.start_pos, 1) == 2
    end

    test "tracks byte offsets" do
      {:ok, tokens} = Tokenizer.tokenize("El gat")

      [first, second] = tokens
      # "El" starts at byte 0
      assert first.span.start_offset == 0
      # "El" is 2 bytes
      assert first.span.end_offset == 2
      # "gat" starts at byte 2 (immediately after "El")
      assert second.span.start_offset == 2
    end

    test "all tokens have valid spans" do
      {:ok, tokens} = Tokenizer.tokenize("L'home col·labora.")

      Enum.each(tokens, fn token ->
        assert is_map(token.span)
        assert Map.has_key?(token.span, :start_pos)
        assert Map.has_key?(token.span, :end_pos)
        assert Map.has_key?(token.span, :start_offset)
        assert Map.has_key?(token.span, :end_offset)
      end)
    end

    test "spans do not overlap" do
      {:ok, tokens} = Tokenizer.tokenize("El gat dorm")

      # Check each adjacent pair
      tokens
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [first, second] ->
        # Second token should start at or after first token ends
        assert second.span.start_offset >= first.span.end_offset
      end)
    end
  end

  describe "tokenize/1 - complex sentences" do
    test "handles sentence with all Catalan features" do
      {:ok, tokens} =
        Tokenizer.tokenize("L'intel·ligent home va del mercat al cafè amb açò.")

      texts = Enum.map(tokens, & &1.text)
      # Apostrophe contraction
      assert "L'" in texts
      # Interpunct word
      assert "intel·ligent" in texts
      # Article contractions
      assert "del" in texts
      assert "al" in texts
      # Diacritic
      assert "cafè" in texts
      assert "açò" in texts
    end

    test "handles long sentence with punctuation" do
      {:ok, tokens} = Tokenizer.tokenize("El gat, que és negre, dorm al sofà.")

      # Check for at least 11 tokens (words and punctuation)
      assert length(tokens) >= 11
      texts = Enum.map(tokens, & &1.text)
      assert "," in texts
      assert "al" in texts
    end

    test "handles question and exclamation" do
      {:ok, tokens} = Tokenizer.tokenize("Com t'ha anat? Molt bé!")

      texts = Enum.map(tokens, & &1.text)
      assert "t'" in texts
      assert "?" in texts
      assert "!" in texts
    end
  end

  describe "tokenize/1 - Token structure" do
    test "tokens are Token structs" do
      {:ok, tokens} = Tokenizer.tokenize("El gat")

      Enum.each(tokens, fn token ->
        assert %Token{} = token
      end)
    end

    test "all tokens have language set to :ca" do
      {:ok, tokens} = Tokenizer.tokenize("El gat dorm")

      Enum.each(tokens, fn token ->
        assert token.language == :ca
      end)
    end

    test "word tokens have nil POS tag initially" do
      {:ok, tokens} = Tokenizer.tokenize("gat")

      [token] = tokens
      assert token.pos_tag == nil
    end

    test "tokens have empty morphology initially" do
      {:ok, tokens} = Tokenizer.tokenize("gat")

      [token] = tokens
      assert token.morphology == %{}
    end

    test "tokens have nil lemma initially" do
      {:ok, tokens} = Tokenizer.tokenize("gat")

      [token] = tokens
      assert token.lemma == nil
    end
  end

  describe "tokenize/1 - error handling" do
    test "returns ok tuple on success" do
      result = Tokenizer.tokenize("El gat")
      assert {:ok, _tokens} = result
    end

    test "handles special characters gracefully" do
      result = Tokenizer.tokenize("@#$%")
      # May return error or empty list - just shouldn't crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "tokenize/2 - with options" do
    test "accepts empty options" do
      {:ok, tokens} = Tokenizer.tokenize("El gat", [])
      assert match?([_, _], tokens)
    end

    test "ignores unknown options" do
      {:ok, tokens} = Tokenizer.tokenize("El gat", unknown_option: true)
      assert match?([_, _], tokens)
    end
  end
end
