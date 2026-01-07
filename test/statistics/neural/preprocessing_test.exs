defmodule Nasty.Statistics.Neural.PreprocessingTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Preprocessing

  describe "normalize_text/2" do
    test "converts text to lowercase by default" do
      assert Preprocessing.normalize_text("Hello World") == "hello world"
    end

    test "preserves case when lowercase: false" do
      assert Preprocessing.normalize_text("Hello World", lowercase: false) == "Hello World"
    end

    test "removes punctuation when enabled" do
      text = "Hello, world! How are you?"
      normalized = Preprocessing.normalize_text(text, remove_punctuation: true)

      assert normalized == "hello world how are you"
    end

    test "preserves punctuation by default" do
      text = "Hello, world!"
      normalized = Preprocessing.normalize_text(text)

      assert normalized == "hello, world!"
    end

    test "normalizes whitespace" do
      text = "Hello   world\t\ntest"
      normalized = Preprocessing.normalize_text(text)

      assert normalized == "hello world test"
    end

    test "handles empty strings" do
      assert Preprocessing.normalize_text("") == ""
    end

    test "handles unicode text" do
      assert Preprocessing.normalize_text("Café") == "café"
      assert Preprocessing.normalize_text("Naïve") == "naïve"
    end
  end

  describe "extract_char_features/2" do
    test "extracts character indices from word" do
      char_vocab = %{"<PAD>" => 0, "<UNK>" => 1, "h" => 2, "e" => 3, "l" => 4, "o" => 5}

      indices = Preprocessing.extract_char_features("hello", char_vocab)

      assert indices == [2, 3, 4, 4, 5]
    end

    test "handles unknown characters with UNK token" do
      char_vocab = %{"<PAD>" => 0, "<UNK>" => 1, "a" => 2}

      indices = Preprocessing.extract_char_features("abc", char_vocab)

      # a, UNK, UNK
      assert indices == [2, 1, 1]
    end

    test "respects max_word_length parameter" do
      char_vocab = %{"<PAD>" => 0, "<UNK>" => 1, "a" => 2}

      indices = Preprocessing.extract_char_features("aaaa", char_vocab, max_word_length: 2)

      assert indices == [2, 2]
    end

    test "handles empty strings" do
      char_vocab = %{"<PAD>" => 0, "<UNK>" => 1}

      assert Preprocessing.extract_char_features("", char_vocab) == []
    end
  end

  describe "extract_word_features/1" do
    test "extracts basic features from word" do
      features = Preprocessing.extract_word_features("Hello")

      assert features.has_uppercase == true
      assert features.has_lowercase == true
      assert features.has_digit == false
      assert features.length == 5
    end

    test "detects digits in words" do
      features = Preprocessing.extract_word_features("hello123")

      assert features.has_digit == true
    end

    test "detects all uppercase words" do
      features = Preprocessing.extract_word_features("HELLO")

      assert features.is_all_uppercase == true
      assert features.has_uppercase == true
      assert features.has_lowercase == false
    end

    test "detects all lowercase words" do
      features = Preprocessing.extract_word_features("hello")

      assert features.is_all_uppercase == false
      assert features.has_uppercase == false
      assert features.has_lowercase == true
    end

    test "detects capitalized words" do
      features = Preprocessing.extract_word_features("Hello")

      assert features.is_capitalized == true
    end

    test "calculates word length correctly" do
      assert Preprocessing.extract_word_features("a").length == 1
      assert Preprocessing.extract_word_features("hello").length == 5
      assert Preprocessing.extract_word_features("").length == 0
    end

    test "detects punctuation" do
      features = Preprocessing.extract_word_features("hello!")

      assert features.has_punctuation == true
    end

    test "handles unicode characters" do
      features = Preprocessing.extract_word_features("café")

      assert features.length == 4
      assert features.has_lowercase == true
    end
  end

  describe "pad_sequence/3" do
    test "pads sequence to specified length" do
      sequence = [1, 2, 3]

      padded = Preprocessing.pad_sequence(sequence, 5)

      assert padded == [1, 2, 3, 0, 0]
    end

    test "truncates sequence if longer than max_length" do
      sequence = [1, 2, 3, 4, 5]

      padded = Preprocessing.pad_sequence(sequence, 3)

      assert padded == [1, 2, 3]
    end

    test "returns sequence unchanged if equal to max_length" do
      sequence = [1, 2, 3]

      padded = Preprocessing.pad_sequence(sequence, 3)

      assert padded == [1, 2, 3]
    end

    test "uses custom padding value" do
      sequence = [1, 2, 3]

      padded = Preprocessing.pad_sequence(sequence, 5, padding_value: -1)

      assert padded == [1, 2, 3, -1, -1]
    end

    test "handles empty sequences" do
      padded = Preprocessing.pad_sequence([], 3)

      assert padded == [0, 0, 0]
    end
  end

  describe "pad_batch/3" do
    test "pads all sequences in batch to same length" do
      batch = [[1, 2], [3, 4, 5], [6]]

      padded = Preprocessing.pad_batch(batch)

      assert padded == [[1, 2, 0], [3, 4, 5], [6, 0, 0]]
    end

    test "uses specified max_length" do
      batch = [[1, 2], [3, 4, 5]]

      padded = Preprocessing.pad_batch(batch, max_length: 4)

      assert padded == [[1, 2, 0, 0], [3, 4, 5, 0]]
    end

    test "truncates sequences longer than max_length" do
      batch = [[1, 2, 3, 4, 5]]

      padded = Preprocessing.pad_batch(batch, max_length: 3)

      assert padded == [[1, 2, 3]]
    end

    test "uses custom padding value" do
      batch = [[1, 2], [3]]

      padded = Preprocessing.pad_batch(batch, padding_value: -1)

      assert padded == [[1, 2], [3, -1]]
    end

    test "handles empty batch" do
      assert Preprocessing.pad_batch([]) == []
    end

    test "handles batch with empty sequences" do
      batch = [[], [1, 2]]

      padded = Preprocessing.pad_batch(batch)

      assert padded == [[0, 0], [1, 2]]
    end
  end

  describe "create_attention_mask/2" do
    test "creates mask for padded sequence" do
      sequence = [1, 2, 3, 0, 0]

      mask = Preprocessing.create_attention_mask(sequence)

      assert mask == [1, 1, 1, 0, 0]
    end

    test "uses custom padding value" do
      sequence = [1, 2, 3, -1, -1]

      mask = Preprocessing.create_attention_mask(sequence, padding_value: -1)

      assert mask == [1, 1, 1, 0, 0]
    end

    test "handles sequences with no padding" do
      sequence = [1, 2, 3, 4, 5]

      mask = Preprocessing.create_attention_mask(sequence)

      assert mask == [1, 1, 1, 1, 1]
    end

    test "handles empty sequences" do
      assert Preprocessing.create_attention_mask([]) == []
    end
  end

  describe "augment_text/2" do
    test "returns not implemented error" do
      assert {:error, :not_implemented} = Preprocessing.augment_text("test", [])
    end
  end

  describe "tokenize_subwords/2" do
    test "returns not implemented error" do
      assert {:error, :not_implemented} = Preprocessing.tokenize_subwords("test", nil)
    end
  end
end
