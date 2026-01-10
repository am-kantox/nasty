# Language Implementation Guide

This guide explains how to add support for a new natural language to Nasty.

## Overview

Adding a new language requires:
1. Implementing the `Nasty.Language.Behaviour`
2. Creating language-specific parsing/tagging modules
3. Registering the language
4. Adding tests and resources

## Step-by-Step Guide

### Step 1: Create Language Module

Create `lib/language/your_language.ex`:

```elixir
defmodule Nasty.Language.YourLanguage do
  @moduledoc """
  Your Language implementation for Nasty.
  
  Provides tokenization, POS tagging, parsing, and rendering for YourLanguage.
  """
  
  @behaviour Nasty.Language.Behaviour
  
  alias Nasty.AST.{Document, Token}
  
  @impl true
  def language_code, do: :yl  # Your ISO 639-1 code
  
  @impl true
  def tokenize(text, _opts \\ []) do
    # Implement tokenization
    # See lib/language/english/tokenizer.ex for reference
    {:ok, tokens}
  end
  
  @impl true
  def tag_pos(tokens, _opts \\ []) do
    # Implement POS tagging
    # See lib/language/english/pos_tagger.ex for reference
    {:ok, tagged_tokens}
  end
  
  @impl true
  def parse(tokens, _opts \\ []) do
    # Implement parsing
    # See lib/language/english.ex for reference
    {:ok, document}
  end
  
  @impl true
  def render(ast, _opts \\ []) do
    # Implement rendering
    # Use Nasty.Rendering.Text as a base
    {:ok, text}
  end
  
  @impl true
  def metadata do
    %{
      version: "1.0.0",
      features: [:tokenization, :pos_tagging, :parsing, :rendering]
    }
  end
end
```

### Step 2: Implement Tokenization

Create `lib/language/your_language/tokenizer.ex`:

```elixir
defmodule Nasty.Language.YourLanguage.Tokenizer do
  @moduledoc"""
  Tokenizer for YourLanguage using NimbleParsec.
  """
  
  import NimbleParsec
  alias Nasty.AST.{Node, Token}
  
  # Define language-specific patterns
  word = ascii_string([?a..?z, ?A..?Z], min: 1)
  punctuation = ascii_char([?., ?!, ?,, ?;, ?:])
  whitespace = ascii_string([?\s, ?\n, ?\t], min: 1)
  
  defparsec :token, choice([word, punctuation])
  
  def tokenize(text) do
    # Implement tokenization logic
    # Return {:ok, [Token.t()]} | {:error, reason}
  end
end
```

### Step 3: Implement POS Tagging

Create `lib/language/your_language/pos_tagger.ex`:

```elixir
defmodule Nasty.Language.YourLanguage.POSTagger do
  @moduledoc """
  Part-of-speech tagger for YourLanguage.
  
  Uses Universal Dependencies tagset for consistency.
  """
  
  alias Nasty.AST.Token
  
  def tag(tokens, _opts \\ []) do
    # Implement tagging logic
    tagged = Enum.map(tokens, &tag_token/1)
    {:ok, tagged}
  end
  
  defp tag_token(token) do
    # Assign POS tag based on rules or statistical model
    %{token | pos_tag: determine_tag(token.text)}
  end
  
  defp determine_tag(word) do
    # Your tagging logic
    :noun  # placeholder
  end
end
```

### Step 4: Implement Morphology

Create `lib/language/your_language/morphology.ex`:

```elixir
defmodule Nasty.Language.YourLanguage.Morphology do
  @moduledoc """
  Morphological analysis for YourLanguage.
  """
  
  def lemmatize(word) do
    # Return base form of word
  end
  
  def analyze(token) do
    # Return morphological features
    %{
      number: :singular,
      tense: :present,
      # ... other features
    }
  end
end
```

### Step 5: Implement Parsing

Create parsing modules for phrase and sentence structure:

`lib/language/your_language/phrase_parser.ex`:
```elixir
defmodule Nasty.Language.YourLanguage.PhraseParser do
  @moduledoc """
  Builds phrase structures (NP, VP, PP) for YourLanguage.
  """
  
  alias Nasty.AST.{NounPhrase, VerbPhrase, PrepositionalPhrase}
  
  def parse_noun_phrase(tokens) do
    # Build NounPhrase from tokens
  end
  
  def parse_verb_phrase(tokens) do
    # Build VerbPhrase from tokens
  end
end
```

`lib/language/your_language/sentence_parser.ex`:
```elixir
defmodule Nasty.Language.YourLanguage.SentenceParser do
  @moduledoc """
  Builds sentence and clause structures for YourLanguage.
  """
  
  alias Nasty.AST.{Sentence, Clause}
  
  def parse_sentence(tokens) do
    # Build Sentence with clauses
  end
end
```

### Step 6: Register Language

Add to `lib/nasty/application.ex`:

```elixir
defmodule Nasty.Application do
  use Application

  def start(_type, _args) do
    # ... existing code ...
    
    # Register languages
    :ok = Nasty.Language.Registry.register(Nasty.Language.English)
    :ok = Nasty.Language.Registry.register(Nasty.Language.YourLanguage)  # Add this
    
    result
  end
end
```

### Step 7: Add Language Detection

Update `lib/language/registry.ex` to support your language:

```elixir
# Add character set scoring
defp character_set_score(text, :yl) do
  # Score based on your language's character set
end

# Add common word scoring
defp common_word_score(words, :yl) do
  common_words = MapSet.new(["word1", "word2", ...])
  score_against_common_words(words, common_words)
end
```

### Step 8: Add Resources

Create resource files in `priv/languages/your_language/`:

```
priv/languages/your_language/
├── lexicons/
│   ├── irregular_verbs.txt
│   ├── irregular_nouns.txt
│   └── stop_words.txt
└── grammars/
    └── phrase_rules.ex
```

### Step 9: Add Tests

Create `test/language/your_language_test.exs`:

```elixir
defmodule Nasty.Language.YourLanguageTest do
  use ExUnit.Case, async: true
  
  alias Nasty.Language.YourLanguage
  
  describe "tokenize/2" do
    test "tokenizes simple sentence" do
      {:ok, tokens} = YourLanguage.tokenize("Simple sentence.", [])
      assert length(tokens) == 3
    end
  end
  
  describe "tag_pos/2" do
    test "tags parts of speech" do
      {:ok, tokens} = YourLanguage.tokenize("Word.", [])
      {:ok, tagged} = YourLanguage.tag_pos(tokens, [])
      assert hd(tagged).pos_tag != nil
    end
  end
  
  describe "parse/2" do
    test "parses to document AST" do
      text = "Simple sentence."
      {:ok, tokens} = YourLanguage.tokenize(text, [])
      {:ok, tagged} = YourLanguage.tag_pos(tokens, [])
      {:ok, doc} = YourLanguage.parse(tagged, [])
      
      assert %Nasty.AST.Document{} = doc
      assert doc.language == :yl
    end
  end
  
  describe "render/2" do
    test "renders AST to text" do
      # Create simple AST
      # Test rendering
    end
  end
end
```

## Language-Specific Considerations

### Word Order

Different languages have different word orders:
- **SVO** (Subject-Verb-Object): English, Spanish
- **SOV**: Japanese, Korean
- **VSO**: Welsh, Arabic (Classical)

Implement word order in your `render/2` function.

### Morphology

Languages vary in morphological complexity:
- **Isolating**: Chinese (minimal morphology)
- **Agglutinative**: Turkish, Finnish (many affixes)
- **Fusional**: Spanish, Russian (inflection)

Implement appropriate morphological analysis.

### Syntax

Consider language-specific syntax:
- **Gender agreement**: Spanish, French
- **Case marking**: German, Russian
- **Postpositions vs. Prepositions**: Japanese vs. English
- **Relative clause placement**: English vs. Japanese

### Punctuation

Handle language-specific punctuation:
- **Quotation marks**: «» in French, 「」 in Japanese
- **Question marks**: ¿? in Spanish
- **Spacing**: No spaces in Chinese

## Universal Dependencies

Always use Universal Dependencies standards:

### POS Tags

Use UD POS tags: `:noun`, `:verb`, `:adj`, etc.

### Dependency Relations

Use UD dependency relations: `:nsubj`, `:obj`, `:obl`, etc.

### Morphological Features

Use UD features: `number: :singular`, `tense: :past`, etc.

## Testing Checklist

- [ ] Tokenization handles edge cases (contractions, URLs, etc.)
- [ ] POS tagging achieves reasonable accuracy (>90%)
- [ ] Parser handles all sentence types
- [ ] Rendering produces grammatical output
- [ ] Language detection works correctly
- [ ] All tests pass
- [ ] Documentation is complete

## Example Implementations

### Spanish Implementation ✓

Spanish is fully implemented and serves as a reference for adding new languages.

See the complete implementation in `lib/language/spanish/`.

**Key Features Implemented**:
- ✓ Gender agreement (el gato, la gata)
- ✓ Inverted punctuation (¿Cómo estás?, ¡Hola!)
- ✓ Verb conjugations (all tenses)
- ✓ Clitic pronouns (dámelo, dáselo)
- ✓ Complete adapter pattern (3 adapters, 843 lines)
- ✓ Spanish discourse markers, stop words, entity lexicons
- ✓ 45% code reduction through generic algorithm reuse

**Quick Reference**:
```elixir
defmodule Nasty.Language.Spanish do
  @behaviour Nasty.Language.Behaviour
  
  @impl true
  def language_code, do: :es
  
  # Complete implementation in lib/language/spanish/
  # See docs/languages/SPANISH_IMPLEMENTATION.md for details
end
```

**Adapters**:
- `Spanish.Adapters.SummarizerAdapter` (241 lines)
- `Spanish.Adapters.EntityRecognizerAdapter` (346 lines)
- `Spanish.Adapters.CoreferenceResolverAdapter` (256 lines)

For a complete guide, see:
- [SPANISH_IMPLEMENTATION.md](languages/SPANISH_IMPLEMENTATION.md) - Full documentation
- `examples/spanish_example.exs` - Working code examples
- `test/language/spanish/` - Test suite

### Catalan Implementation ✓

Catalan is fully implemented (Phases 1-7) and demonstrates language-specific features.

See the implementation in `lib/language/catalan/` (7 modules) and documentation in `docs/languages/CATALAN.md`.

**Key Features Implemented**:
- ✓ Interpunct handling (col·laborar, intel·ligent)
- ✓ Apostrophe contractions (l', d', s', n', m', t')
- ✓ Article contractions (del, al, pel)
- ✓ 10 Catalan diacritics (à, è, é, í, ï, ò, ó, ú, ü, ç)
- ✓ 3 verb conjugation classes (-ar, -re, -ir)
- ✓ Post-nominal adjectives and flexible word order
- ✓ Full parsing pipeline (phrase/sentence parsing, dependencies, NER)
- ✓ Externalized grammar rules (phrase_rules.exs, dependency_rules.exs)
- ✓ 74 comprehensive tests, 100% passing

**Quick Reference**:
```elixir
defmodule Nasty.Language.Catalan do
  @behaviour Nasty.Language.Behaviour
  
  @impl true
  def language_code, do: :ca
  
  # Complete implementation in lib/language/catalan/
  # See docs/languages/CATALAN.md for details
end
```

**Modules**:
- `Catalan.Tokenizer` (145 lines)
- `Catalan.POSTagger` (509 lines)
- `Catalan.Morphology` (519 lines)
- `Catalan.PhraseParser` (334 lines)
- `Catalan.SentenceParser` (281 lines)
- `Catalan.DependencyExtractor` (226 lines)
- `Catalan.EntityRecognizer` (285 lines)

For complete details, see:
- [CATALAN.md](languages/CATALAN.md) - Full documentation
- `test/language/catalan/` - Test suite (74 tests)

## Resources

- [Universal Dependencies](https://universaldependencies.org/)
- [ISO 639-1 Language Codes](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes)
- [NimbleParsec Documentation](https://hexdocs.pm/nimble_parsec)

## See Also

- [Architecture](ARCHITECTURE.md)
- [API Documentation](API.md)
- [AST Reference](AST_REFERENCE.md)
