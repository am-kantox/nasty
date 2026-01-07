defmodule Nasty.Statistics.Neural.EmbeddingsTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Embeddings

  describe "build_vocabulary/2" do
    test "builds vocabulary from list of token lists" do
      tokens = [["hello", "world"], ["hello", "elixir"]]

      vocab = Embeddings.build_vocabulary(tokens)

      assert is_map(vocab)
      assert Map.has_key?(vocab, "<PAD>")
      assert Map.has_key?(vocab, "<UNK>")
      assert Map.has_key?(vocab, "hello")
      assert Map.has_key?(vocab, "world")
      assert Map.has_key?(vocab, "elixir")
    end

    test "assigns PAD token to index 0" do
      tokens = [["test"]]
      vocab = Embeddings.build_vocabulary(tokens)

      assert vocab["<PAD>"] == 0
    end

    test "assigns UNK token to index 1" do
      tokens = [["test"]]
      vocab = Embeddings.build_vocabulary(tokens)

      assert vocab["<UNK>"] == 1
    end

    test "filters rare words with min_freq" do
      tokens = [["rare"], ["common", "common", "common"]]

      vocab = Embeddings.build_vocabulary(tokens, min_freq: 2)

      assert Map.has_key?(vocab, "common")
      refute Map.has_key?(vocab, "rare")
    end

    test "handles empty token lists" do
      vocab = Embeddings.build_vocabulary([])

      # Only PAD and UNK
      assert map_size(vocab) == 2
      assert Map.has_key?(vocab, "<PAD>")
      assert Map.has_key?(vocab, "<UNK>")
    end

    test "preserves case sensitivity" do
      tokens = [["Hello", "hello", "HELLO"]]

      vocab = Embeddings.build_vocabulary(tokens)

      assert Map.has_key?(vocab, "Hello")
      assert Map.has_key?(vocab, "hello")
      assert Map.has_key?(vocab, "HELLO")
      assert vocab["Hello"] != vocab["hello"]
    end

    test "assigns unique indices to each word" do
      tokens = [["one", "two", "three"]]
      vocab = Embeddings.build_vocabulary(tokens)

      indices = Map.values(vocab)
      assert length(indices) == length(Enum.uniq(indices))
    end
  end

  describe "build_char_vocabulary/2" do
    test "builds character vocabulary from list of token lists" do
      tokens = [["hello", "world"]]

      vocab = Embeddings.build_char_vocabulary(tokens)

      assert Map.has_key?(vocab, "<PAD>")
      assert Map.has_key?(vocab, "<UNK>")
      assert Map.has_key?(vocab, "h")
      assert Map.has_key?(vocab, "e")
      assert Map.has_key?(vocab, "l")
      assert Map.has_key?(vocab, "o")
      assert Map.has_key?(vocab, "w")
      assert Map.has_key?(vocab, "r")
      assert Map.has_key?(vocab, "d")
    end

    test "includes all characters from all tokens" do
      tokens = [["abc", "xyz"]]

      vocab = Embeddings.build_char_vocabulary(tokens)

      for char <- ~w(a b c x y z) do
        assert Map.has_key?(vocab, char)
      end
    end

    test "handles unicode characters" do
      tokens = [["café", "naïve"]]

      vocab = Embeddings.build_char_vocabulary(tokens)

      assert Map.has_key?(vocab, "é")
      assert Map.has_key?(vocab, "ï")
    end
  end

  describe "word_to_index/3" do
    setup do
      vocab = %{"<PAD>" => 0, "<UNK>" => 1, "hello" => 2, "world" => 3}
      {:ok, vocab: vocab}
    end

    test "returns correct index for known word", %{vocab: vocab} do
      assert Embeddings.word_to_index("hello", vocab) == 2
      assert Embeddings.word_to_index("world", vocab) == 3
    end

    test "returns UNK index for unknown word", %{vocab: vocab} do
      assert Embeddings.word_to_index("unknown", vocab) == 1
    end

    test "uses custom UNK index when provided", %{vocab: vocab} do
      custom_unk = 99
      assert Embeddings.word_to_index("unknown", vocab, custom_unk) == custom_unk
    end
  end

  describe "words_to_indices/3" do
    setup do
      vocab = %{"<PAD>" => 0, "<UNK>" => 1, "hello" => 2, "world" => 3}
      {:ok, vocab: vocab}
    end

    test "converts list of words to indices", %{vocab: vocab} do
      words = ["hello", "world"]

      assert Embeddings.words_to_indices(words, vocab) == [2, 3]
    end

    test "handles mix of known and unknown words", %{vocab: vocab} do
      words = ["hello", "unknown", "world"]

      assert Embeddings.words_to_indices(words, vocab) == [2, 1, 3]
    end

    test "handles empty list", %{vocab: vocab} do
      assert Embeddings.words_to_indices([], vocab) == []
    end
  end

  describe "create_embedding_layer/2" do
    test "creates embedding layer with correct vocabulary size" do
      vocab = %{"<PAD>" => 0, "<UNK>" => 1, "hello" => 2}

      layer = Embeddings.create_embedding_layer(vocab, embedding_dim: 50)

      assert is_function(layer, 1)
    end

    test "uses default embedding dimension of 300" do
      vocab = %{"<PAD>" => 0, "<UNK>" => 1}

      layer = Embeddings.create_embedding_layer(vocab)

      assert is_function(layer, 1)
    end
  end

  describe "create_char_embedding_layer/2" do
    test "creates character embedding layer" do
      vocab = %{"<PAD>" => 0, "<UNK>" => 1, "a" => 2, "b" => 3}

      layer = Embeddings.create_char_embedding_layer(vocab, embedding_dim: 25)

      assert is_function(layer, 1)
    end

    test "uses default embedding dimension of 50" do
      vocab = %{"<PAD>" => 0, "<UNK>" => 1}

      layer = Embeddings.create_char_embedding_layer(vocab)

      assert is_function(layer, 1)
    end
  end

  describe "load_glove/2" do
    test "returns file not found error for non-existent file" do
      assert {:error, :file_not_found} = Embeddings.load_glove("fake_path.txt", %{})
    end
  end
end
