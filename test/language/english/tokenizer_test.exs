defmodule Nasty.Language.English.TokenizerTest do
  use ExUnit.Case, async: true

  alias Nasty.Language.English.Tokenizer

  doctest Nasty.Language.English.Tokenizer

  describe "simple tokenization" do
    test "tokenizes single word" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello")
      assert length(tokens) == 1
      assert hd(tokens).text == "Hello"
      assert hd(tokens).language == :en
    end

    test "tokenizes two words" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello world")
      assert length(tokens) == 2
      assert Enum.map(tokens, & &1.text) == ["Hello", "world"]
    end

    test "tokenizes sentence with period" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello world.")
      assert length(tokens) == 3
      assert Enum.map(tokens, & &1.text) == ["Hello", "world", "."]
    end

    test "handles multiple spaces between words" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello    world")
      assert length(tokens) == 2
      assert Enum.map(tokens, & &1.text) == ["Hello", "world"]
    end
  end

  describe "contractions" do
    test "tokenizes don't" do
      assert {:ok, tokens} = Tokenizer.tokenize("don't")
      assert length(tokens) == 1
      assert hd(tokens).text == "don't"
    end

    test "tokenizes I'm" do
      assert {:ok, tokens} = Tokenizer.tokenize("I'm")
      assert length(tokens) == 1
      assert hd(tokens).text == "I'm"
    end

    test "tokenizes we're, they're, you're" do
      assert {:ok, tokens} = Tokenizer.tokenize("we're happy")
      assert Enum.at(tokens, 0).text == "we're"

      assert {:ok, tokens} = Tokenizer.tokenize("they're here")
      assert Enum.at(tokens, 0).text == "they're"
    end

    test "tokenizes I've, we've, they've" do
      assert {:ok, tokens} = Tokenizer.tokenize("I've been")
      assert Enum.at(tokens, 0).text == "I've"
    end

    test "tokenizes I'll, we'll, they'll" do
      assert {:ok, tokens} = Tokenizer.tokenize("I'll go")
      assert Enum.at(tokens, 0).text == "I'll"
    end

    test "tokenizes I'd, we'd, they'd" do
      assert {:ok, tokens} = Tokenizer.tokenize("I'd like")
      assert Enum.at(tokens, 0).text == "I'd"
    end

    test "tokenizes sentence with multiple contractions" do
      assert {:ok, tokens} = Tokenizer.tokenize("I don't know what you're doing.")
      texts = Enum.map(tokens, & &1.text)
      assert "don't" in texts
      assert "you're" in texts
    end
  end

  describe "punctuation" do
    test "tokenizes comma" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello, world")
      assert Enum.map(tokens, & &1.text) == ["Hello", ",", "world"]
    end

    test "tokenizes semicolon and colon" do
      assert {:ok, tokens} = Tokenizer.tokenize("First; second: third")
      texts = Enum.map(tokens, & &1.text)
      assert ";" in texts
      assert ":" in texts
    end

    test "tokenizes exclamation and question marks" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello! How are you?")
      texts = Enum.map(tokens, & &1.text)
      assert "!" in texts
      assert "?" in texts
    end

    test "tokenizes parentheses" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello (world)")
      texts = Enum.map(tokens, & &1.text)
      assert "(" in texts
      assert ")" in texts
    end

    test "tokenizes brackets" do
      assert {:ok, tokens} = Tokenizer.tokenize("[Important] note")
      texts = Enum.map(tokens, & &1.text)
      assert "[" in texts
      assert "]" in texts
    end

    test "tokenizes quotes" do
      assert {:ok, tokens} = Tokenizer.tokenize(~s("Hello" 'world'))
      texts = Enum.map(tokens, & &1.text)
      assert "\"" in texts
      assert "'" in texts
    end
  end

  describe "numbers" do
    test "tokenizes integers" do
      assert {:ok, tokens} = Tokenizer.tokenize("I have 42 apples")
      assert Enum.at(tokens, 2).text == "42"
      assert Enum.at(tokens, 2).pos_tag == :num
    end

    test "tokenizes decimals" do
      assert {:ok, tokens} = Tokenizer.tokenize("Price is 19.99")
      assert Enum.at(tokens, 2).text == "19.99"
      assert Enum.at(tokens, 2).pos_tag == :num
    end

    test "tokenizes year" do
      assert {:ok, tokens} = Tokenizer.tokenize("Year 2026")
      assert Enum.at(tokens, 1).text == "2026"
    end
  end

  describe "hyphenated words" do
    test "tokenizes hyphenated word" do
      assert {:ok, tokens} = Tokenizer.tokenize("well-known")
      assert length(tokens) == 1
      assert hd(tokens).text == "well-known"
    end

    test "tokenizes multiple hyphenated words" do
      assert {:ok, tokens} = Tokenizer.tokenize("twenty-one well-known items")
      assert Enum.at(tokens, 0).text == "twenty-one"
      assert Enum.at(tokens, 1).text == "well-known"
    end
  end

  describe "position tracking" do
    test "tracks byte offsets correctly" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello world")

      first = Enum.at(tokens, 0)
      assert first.span.start_offset == 0
      # "Hello"
      assert first.span.end_offset == 5

      second = Enum.at(tokens, 1)
      # After space
      assert second.span.start_offset == 6
      # "world"
      assert second.span.end_offset == 11
    end

    test "tracks line and column" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello world")

      first = Enum.at(tokens, 0)
      assert first.span.start_pos == {1, 0}

      second = Enum.at(tokens, 1)
      assert second.span.start_pos == {1, 6}
    end

    test "handles position tracking for contractions" do
      assert {:ok, tokens} = Tokenizer.tokenize("I'm happy")

      contraction = Enum.at(tokens, 0)
      assert contraction.text == "I'm"
      assert contraction.span.start_offset == 0
      assert contraction.span.end_offset == byte_size("I'm")
    end
  end

  describe "complex sentences" do
    test "tokenizes complex sentence" do
      text = "Hello, world! I'm happy that you're here."
      assert {:ok, tokens} = Tokenizer.tokenize(text)

      texts = Enum.map(tokens, & &1.text)
      assert "Hello" in texts
      assert "," in texts
      assert "world" in texts
      assert "!" in texts
      assert "I'm" in texts
      assert "happy" in texts
      assert "that" in texts
      assert "you're" in texts
      assert "here" in texts
      assert "." in texts
    end

    test "tokenizes sentence with numbers and punctuation" do
      text = "There are 42 items (worth $19.99 each)."
      assert {:ok, tokens} = Tokenizer.tokenize(text)

      texts = Enum.map(tokens, & &1.text)
      assert "42" in texts
      assert "19.99" in texts
      assert "(" in texts
      assert ")" in texts
    end
  end

  describe "edge cases" do
    test "handles empty string" do
      assert {:ok, tokens} = Tokenizer.tokenize("")
      assert tokens == []
    end

    test "handles only whitespace" do
      assert {:ok, tokens} = Tokenizer.tokenize("   ")
      assert tokens == []
    end

    test "handles only punctuation" do
      assert {:ok, tokens} = Tokenizer.tokenize("...")
      assert length(tokens) == 3
      assert Enum.all?(tokens, &(&1.text == "."))
    end

    test "handles uppercase and lowercase" do
      assert {:ok, tokens} = Tokenizer.tokenize("HELLO World")
      assert Enum.map(tokens, & &1.text) == ["HELLO", "World"]
    end
  end

  describe "token properties" do
    test "all tokens have language set to :en" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello world")
      assert Enum.all?(tokens, &(&1.language == :en))
    end

    test "all tokens have valid spans" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello world")

      Enum.each(tokens, fn token ->
        assert is_map(token.span)
        assert Map.has_key?(token.span, :start_pos)
        assert Map.has_key?(token.span, :end_pos)
        assert Map.has_key?(token.span, :start_offset)
        assert Map.has_key?(token.span, :end_offset)
      end)
    end

    test "punctuation tokens have :punct pos_tag" do
      assert {:ok, tokens} = Tokenizer.tokenize("Hello, world.")

      comma = Enum.at(tokens, 1)
      assert comma.pos_tag == :punct

      period = Enum.at(tokens, 3)
      assert period.pos_tag == :punct
    end

    test "number tokens have :num pos_tag" do
      assert {:ok, tokens} = Tokenizer.tokenize("I have 42 items")

      number = Enum.at(tokens, 2)
      assert number.pos_tag == :num
    end
  end
end
