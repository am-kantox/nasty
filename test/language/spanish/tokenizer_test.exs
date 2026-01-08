defmodule Nasty.Language.Spanish.TokenizerTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.Spanish.Tokenizer

  describe "tokenize/1" do
    test "tokenizes simple Spanish sentence" do
      {:ok, tokens} = Tokenizer.tokenize("El gato se sentó.")

      assert match?([_, _, _, _, _], tokens)
      assert Enum.map(tokens, & &1.text) == ["El", "gato", "se", "sentó", "."]
    end

    test "handles Spanish punctuation ¿? and ¡!" do
      {:ok, tokens} = Tokenizer.tokenize("¿Cómo estás? ¡Muy bien!")

      texts = Enum.map(tokens, & &1.text)
      assert "¿" in texts
      assert "?" in texts
      assert "¡" in texts
      assert "!" in texts
    end

    test "handles contractions del and al" do
      {:ok, tokens} = Tokenizer.tokenize("Voy del mercado al parque.")

      assert match?([_, _, _, _, _, _], tokens)
      assert Enum.map(tokens, & &1.text) == ["Voy", "del", "mercado", "al", "parque", "."]
    end

    test "handles clitics dámelo" do
      {:ok, tokens} = Tokenizer.tokenize("Dámelo ahora.")

      texts = Enum.map(tokens, & &1.text)
      assert "Dámelo" in texts or ("Dá" in texts and "me" in texts and "lo" in texts)
    end

    test "handles accented characters" do
      {:ok, tokens} = Tokenizer.tokenize("José María ñoño.")

      assert match?([_, _, _, _], tokens)
      texts = Enum.map(tokens, & &1.text)
      assert "José" in texts
      assert "María" in texts
      assert "ñoño" in texts
    end

    test "tracks position information" do
      {:ok, tokens} = Tokenizer.tokenize("Hola mundo")

      [first | _] = tokens
      assert elem(first.span.start_pos, 0) == 1
      assert elem(first.span.start_pos, 1) >= 0
    end
  end
end
