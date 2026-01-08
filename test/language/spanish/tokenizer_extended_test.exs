defmodule Nasty.Language.Spanish.TokenizerExtendedTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.Spanish.Tokenizer

  describe "Spanish-specific punctuation" do
    test "correctly tokenizes inverted question marks ¿?" do
      {:ok, tokens} = Tokenizer.tokenize("¿Cómo estás?")

      texts = Enum.map(tokens, & &1.text)
      assert "¿" in texts
      assert "?" in texts
      assert match?([_, _, _, _], tokens)
    end

    test "correctly tokenizes inverted exclamation marks ¡!" do
      {:ok, tokens} = Tokenizer.tokenize("¡Hola mundo!")

      texts = Enum.map(tokens, & &1.text)
      assert "¡" in texts
      assert "!" in texts
      assert match?([_, _, _, _], tokens)
    end

    test "handles guillemets « »" do
      {:ok, tokens} = Tokenizer.tokenize("Dijo «hola» ayer.")

      texts = Enum.map(tokens, & &1.text)
      assert "«" in texts
      assert "»" in texts
    end

    test "handles single guillemets ‹ ›" do
      {:ok, tokens} = Tokenizer.tokenize("Usó ‹comillas› aquí.")

      texts = Enum.map(tokens, & &1.text)
      assert "‹" in texts
      assert "›" in texts
    end

    test "handles euro symbol €" do
      {:ok, tokens} = Tokenizer.tokenize("Cuesta 25€ exactamente.")

      texts = Enum.map(tokens, & &1.text)
      assert "€" in texts
      assert "25" in texts
    end

    test "handles em dash —" do
      {:ok, tokens} = Tokenizer.tokenize("Es importante—muy importante—hacerlo.")

      texts = Enum.map(tokens, & &1.text)
      assert "—" in texts
    end

    test "handles mixed Spanish punctuation" do
      {:ok, tokens} = Tokenizer.tokenize("¿Verdad? ¡Sí! «Excelente».")

      # ¿ Verdad ? ¡ Sí ! « Excelente » . = 10 tokens
      assert match?([_, _, _, _, _, _, _, _, _, _], tokens)
      assert Enum.all?(tokens, &(&1.language == :es))
    end
  end

  describe "Spanish clitics" do
    test "tokenizes verb with single clitic as one token" do
      {:ok, tokens} = Tokenizer.tokenize("Dámelo ahora")

      texts = Enum.map(tokens, & &1.text)
      # Clitic should be attached to verb or split
      assert "Dámelo" in texts or ("Dá" in texts and "me" in texts and "lo" in texts)
    end

    test "handles imperative with multiple clitics" do
      {:ok, tokens} = Tokenizer.tokenize("Cómetelo rápido")

      texts = Enum.map(tokens, & &1.text)
      assert "Cómetelo" in texts or "Cóme" in texts
    end

    test "handles dáselo pattern" do
      {:ok, tokens} = Tokenizer.tokenize("Dáselo a Juan")

      texts = Enum.map(tokens, & &1.text)
      assert "Dáselo" in texts or "Dá" in texts
    end

    test "distinguishes clitics from regular words" do
      {:ok, tokens} = Tokenizer.tokenize("dame pan")

      texts = Enum.map(tokens, & &1.text)
      # dame could be verb+clitic or regular word
      assert "dame" in texts or ("da" in texts and "me" in texts)
    end
  end

  describe "Spanish contractions" do
    test "tokenizes del as separate token" do
      {:ok, tokens} = Tokenizer.tokenize("Vengo del mercado")

      texts = Enum.map(tokens, & &1.text)
      assert "del" in texts
      assert match?([_, _, _], tokens)
    end

    test "tokenizes al as separate token" do
      {:ok, tokens} = Tokenizer.tokenize("Voy al parque")

      texts = Enum.map(tokens, & &1.text)
      assert "al" in texts
      assert match?([_, _, _], tokens)
    end

    test "handles capitalized contractions" do
      {:ok, tokens} = Tokenizer.tokenize("Del mercado Al parque")

      texts = Enum.map(tokens, & &1.text)
      assert "Del" in texts
      assert "Al" in texts
    end

    test "distinguishes contractions from similar words" do
      {:ok, tokens} = Tokenizer.tokenize("Al alma del corazón")

      texts = Enum.map(tokens, & &1.text)
      assert "Al" in texts
      assert "del" in texts
      assert "alma" in texts
    end
  end

  describe "Spanish accented characters" do
    test "handles acute accents á é í ó ú" do
      {:ok, tokens} = Tokenizer.tokenize("José comió después allí aquí")

      texts = Enum.map(tokens, & &1.text)
      assert "José" in texts
      assert "comió" in texts
      assert "después" in texts
      assert "allí" in texts
      assert "aquí" in texts
    end

    test "handles ñ character" do
      {:ok, tokens} = Tokenizer.tokenize("El niño español")

      texts = Enum.map(tokens, & &1.text)
      assert "niño" in texts
      assert "español" in texts
    end

    test "handles ü character" do
      {:ok, tokens} = Tokenizer.tokenize("La cigüeña vuela")

      texts = Enum.map(tokens, & &1.text)
      assert "cigüeña" in texts
    end

    test "handles uppercase accented characters" do
      {:ok, tokens} = Tokenizer.tokenize("JOSÉ MARÍA LÓPEZ")

      texts = Enum.map(tokens, & &1.text)
      assert "JOSÉ" in texts
      assert "MARÍA" in texts
      assert "LÓPEZ" in texts
    end

    test "handles mixed accented text" do
      {:ok, tokens} = Tokenizer.tokenize("Año pasó rápidamente según Ramón")

      # Año pasó rápidamente según Ramón = 5 tokens
      assert match?([_, _, _, _, _], tokens)
      assert Enum.all?(tokens, &(&1.language == :es))
    end
  end

  describe "Spanish abbreviations" do
    test "tokenizes Sr. as single token" do
      {:ok, tokens} = Tokenizer.tokenize("El Sr. García llegó")

      texts = Enum.map(tokens, & &1.text)
      assert "Sr." in texts
    end

    test "tokenizes Sra. as single token" do
      {:ok, tokens} = Tokenizer.tokenize("La Sra. López habló")

      texts = Enum.map(tokens, & &1.text)
      assert "Sra." in texts
    end

    test "tokenizes Dr. and Dra." do
      {:ok, tokens} = Tokenizer.tokenize("El Dr. y la Dra. vinieron")

      texts = Enum.map(tokens, & &1.text)
      assert "Dr." in texts
      assert "Dra." in texts
    end

    test "tokenizes etc. correctly" do
      {:ok, tokens} = Tokenizer.tokenize("Frutas, verduras, etc. están aquí")

      texts = Enum.map(tokens, & &1.text)
      assert "etc." in texts
    end

    test "distinguishes abbreviations from sentence endings" do
      {:ok, tokens} = Tokenizer.tokenize("El Sr. García. Llegó ayer.")

      texts = Enum.map(tokens, & &1.text)
      assert "Sr." in texts
      # Period after García should be separate
      assert "." in texts
    end
  end

  describe "position tracking" do
    test "tracks accurate byte offsets for accented characters" do
      {:ok, tokens} = Tokenizer.tokenize("José María")

      [first, second] = tokens
      assert first.text == "José"
      assert second.text == "María"

      # Accented characters take multiple bytes
      assert first.span.start_offset == 0
      assert first.span.end_offset == byte_size("José")
      assert second.span.start_offset > first.span.end_offset
    end

    test "tracks line and column positions correctly" do
      {:ok, tokens} = Tokenizer.tokenize("Hola mundo")

      [first, second] = tokens
      assert elem(first.span.start_pos, 0) == 1
      assert elem(second.span.start_pos, 0) == 1
    end

    test "handles multiline text position tracking" do
      {:ok, tokens} = Tokenizer.tokenize("Primera línea\nSegunda línea")

      assert Enum.all?(tokens, fn token ->
               {line, _col} = token.span.start_pos
               line in [1, 2]
             end)
    end
  end

  describe "edge cases" do
    test "handles empty string" do
      {:ok, tokens} = Tokenizer.tokenize("")

      assert tokens == []
    end

    test "handles whitespace-only string" do
      {:ok, tokens} = Tokenizer.tokenize("   \n  \t  ")

      assert tokens == []
    end

    test "handles single punctuation mark" do
      {:ok, tokens} = Tokenizer.tokenize("¿")

      assert match?([_], tokens)
      assert hd(tokens).text == "¿"
    end

    test "handles long Spanish text" do
      long_text = String.duplicate("El gato duerme. ", 100)
      {:ok, tokens} = Tokenizer.tokenize(long_text)

      assert length(tokens) > 200
      assert Enum.all?(tokens, &(&1.language == :es))
    end

    test "handles numbers in Spanish context" do
      {:ok, tokens} = Tokenizer.tokenize("Tengo 25 años y 100€")

      texts = Enum.map(tokens, & &1.text)
      assert "25" in texts
      assert "100" in texts
      assert "€" in texts
    end

    test "handles hyphenated words" do
      {:ok, tokens} = Tokenizer.tokenize("bien-estar medio-día")

      texts = Enum.map(tokens, & &1.text)
      assert "bien-estar" in texts or "bien" in texts
      assert "medio-día" in texts or "medio" in texts
    end
  end
end
