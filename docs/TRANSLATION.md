# Translation System Guide

Comprehensive guide to Nasty's AST-based translation system for natural language translation between English, Spanish, and Catalan.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [Core Components](#core-components)
5. [Translation Pipeline](#translation-pipeline)
6. [Morphological Agreement](#morphological-agreement)
7. [Word Order Rules](#word-order-rules)
8. [Lexicon Management](#lexicon-management)
9. [Supported Language Pairs](#supported-language-pairs)
10. [Customization](#customization)
11. [Best Practices](#best-practices)
12. [Limitations](#limitations)

## Overview

Nasty's translation system operates at the Abstract Syntax Tree (AST) level, providing grammatically-aware translation that preserves linguistic structure. Unlike token-by-token machine translation, this approach:

- Preserves grammatical relationships
- Applies morphological agreement rules
- Handles language-specific word order
- Supports bidirectional translation
- Enables roundtrip translation with minimal loss

## Architecture

### System Diagram

```
┌─────────────────┐
│  Source Text    │
│   (Language A)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Parse to AST   │
│   (Source Lang) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ AST Transform   │  ← ASTTransformer
│  (Structural)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Token Translate │  ← TokenTranslator
│ (Lemma mapping) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Agreement     │  ← Agreement
│  (Morphology)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Word Order     │  ← WordOrder
│  (Reordering)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Render to Text │  ← AST.Renderer
│   (Target Lang) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Target Text    │
│   (Language B)  │
└─────────────────┘
```

### Module Structure

```
lib/
├── translation/
│   ├── translator.ex           # Main API
│   ├── ast_transformer.ex      # AST node transformation
│   ├── token_translator.ex     # Token-level translation
│   ├── agreement.ex            # Morphological agreement
│   ├── word_order.ex           # Word order rules
│   └── lexicon_loader.ex       # Lexicon management
├── ast/
│   └── renderer.ex             # AST to text rendering
└── priv/
    └── translation/
        └── lexicons/
            ├── en_es.exs       # English → Spanish
            ├── es_en.exs       # Spanish → English
            ├── en_ca.exs       # English → Catalan
            └── ca_en.exs       # Catalan → English
```

## Quick Start

### Basic Translation

```elixir
alias Nasty.Language.{English, Spanish}
alias Nasty.Translation.Translator

# English to Spanish
{:ok, doc_en} = Nasty.parse("The cat runs.", language: :en)
{:ok, doc_es} = Translator.translate(doc_en, :es)
{:ok, text_es} = Nasty.render(doc_es)
IO.puts(text_es)
# => "El gato corre."

# Spanish to English
{:ok, doc_es} = Nasty.parse("El perro grande.", language: :es)
{:ok, doc_en} = Translator.translate(doc_es, :en)
{:ok, text_en} = Nasty.render(doc_en)
IO.puts(text_en)
# => "The big dog."
```

### Using the High-Level API

```elixir
# Translate text directly
{:ok, text_es} = Nasty.translate_text("The quick cat.", :en, :es)
# => "El gato rápido."

# Or with explicit parsing
{:ok, ast} = Nasty.parse("The house is big.", language: :en)
{:ok, translated_ast} = Nasty.translate(ast, :es)
{:ok, text} = Nasty.render(translated_ast)
```

## Core Components

### 1. ASTTransformer

Transforms AST nodes between language structures.

**Module:** `Nasty.Translation.ASTTransformer`

**Functions:**
- `transform_document/2` - Transform entire document
- `transform_sentence/2` - Transform sentence
- `transform_phrase/2` - Transform phrase structures
- `transform_clause/2` - Transform clause

**Example:**
```elixir
alias Nasty.Translation.ASTTransformer

{:ok, spanish_doc} = ASTTransformer.transform_document(english_doc, :es)
```

### 2. TokenTranslator

Performs lemma-to-lemma translation with POS awareness.

**Module:** `Nasty.Translation.TokenTranslator`

**Functions:**
- `translate_token/3` - Translate single token
- `translate_with_morphology/3` - Translate preserving morphology
- `lookup_translation/3` - Lookup in lexicon

**Example:**
```elixir
alias Nasty.Translation.TokenTranslator

# cat (noun) → gato (noun)
translated = TokenTranslator.translate_token(token, :en, :es)

# Preserves morphology
# cats (noun, plural) → gatos (noun, plural)
translated = TokenTranslator.translate_with_morphology(token, :en, :es)
```

### 3. Agreement

Enforces morphological agreement rules (gender, number, person).

**Module:** `Nasty.Translation.Agreement`

**Functions:**
- `apply_agreement/2` - Apply all agreement rules
- `apply_determiner_noun/2` - Determiner-noun agreement
- `apply_noun_adjective/2` - Noun-adjective agreement
- `apply_subject_verb/2` - Subject-verb agreement

**Example:**
```elixir
alias Nasty.Translation.Agreement

# Ensure "el gato" (masculine) not "la gato"
adjusted = Agreement.apply_agreement(tokens, :es)

# Ensure "los gatos grandes" (plural agreement throughout)
adjusted = Agreement.apply_agreement(tokens, :es)
```

### 4. WordOrder

Applies language-specific word order transformations.

**Module:** `Nasty.Translation.WordOrder`

**Functions:**
- `apply_order/2` - Apply all word order rules
- `apply_adjective_order/2` - Position adjectives correctly
- `apply_svo_order/2` - Subject-Verb-Object ordering
- `handle_clitics/2` - Clitic placement

**Example:**
```elixir
alias Nasty.Translation.WordOrder

# "the big house" → "la casa grande" (adjective after noun)
ordered = WordOrder.apply_order(phrase, :es)

# "I eat it" → "Lo como" (clitic before verb in Spanish)
ordered = WordOrder.handle_clitics(phrase, :es)
```

### 5. LexiconLoader

Manages bidirectional lexicons with ETS caching for fast lookup.

**Module:** `Nasty.Translation.LexiconLoader`

**Functions:**
- `load/2` - Load lexicon for language pair
- `lookup/3` - Look up translation
- `reload/2` - Reload lexicon from file

**Example:**
```elixir
alias Nasty.Translation.LexiconLoader

# Load lexicon (cached in ETS)
{:ok, lexicon} = LexiconLoader.load(:en, :es)

# Bidirectional lookup
"gato" = LexiconLoader.lookup(lexicon, "cat", :noun)
"cat" = LexiconLoader.lookup(lexicon, "gato", :noun)

# Reload after editing lexicon file
LexiconLoader.reload(:en, :es)
```

### 6. AST.Renderer

Renders AST back to natural language text.

**Module:** `Nasty.AST.Renderer`

**Functions:**
- `render_document/1` - Render complete document
- `render_sentence/1` - Render single sentence
- `render_phrase/1` - Render phrase
- `render_tokens/1` - Render token sequence

**Example:**
```elixir
alias Nasty.AST.Renderer

# Render with proper spacing and punctuation
{:ok, text} = Renderer.render_document(document)

# Render phrase
{:ok, text} = Renderer.render_phrase(noun_phrase)
# => "el gato grande"
```

## Translation Pipeline

### Step-by-Step Process

#### 1. Parse Source Text

```elixir
alias Nasty.Language.English

text = "The quick brown fox jumps."
{:ok, tokens} = English.tokenize(text)
{:ok, tagged} = English.tag_pos(tokens)
{:ok, doc} = English.parse(tagged)
```

**AST Structure:**
```
Document (language: :en)
└── Paragraph
    └── Sentence
        └── Clause
            ├── Subject: NounPhrase
            │   ├── Determiner: "The"
            │   ├── Modifiers: ["quick", "brown"]
            │   └── Head: "fox"
            └── Predicate: VerbPhrase
                └── Head: "jumps"
```

#### 2. Transform AST Structure

```elixir
alias Nasty.Translation.ASTTransformer

{:ok, doc_es} = ASTTransformer.transform_document(doc, :es)
```

Changes `language: :en` to `language: :es` throughout.

#### 3. Translate Tokens

```elixir
alias Nasty.Translation.TokenTranslator

# For each token in AST:
# "fox" (noun) → "zorro" (noun)
# "jumps" (verb) → "salta" (verb)
```

#### 4. Apply Agreement

```elixir
alias Nasty.Translation.Agreement

# Ensure gender/number agreement:
# "el" (masculine singular) + "zorro" (masculine singular) ✓
# "los" (masculine plural) + "zorros" (masculine plural) ✓
```

#### 5. Apply Word Order

```elixir
alias Nasty.Translation.WordOrder

# "the quick brown fox" → "el zorro rápido pardo"
# (adjectives after noun in Spanish for most adjectives)
```

#### 6. Render to Text

```elixir
alias Nasty.AST.Renderer

{:ok, text} = Renderer.render_document(doc_es)
# => "El zorro rápido pardo salta."
```

## Morphological Agreement

### Gender Agreement

Spanish and Catalan have grammatical gender (masculine/feminine).

**Determiner-Noun:**
```elixir
# English: "the cat"
# Spanish: "el gato" (masculine)

# English: "the house"
# Spanish: "la casa" (feminine)
```

**Noun-Adjective:**
```elixir
# English: "the red car"
# Spanish: "el carro rojo" (masculine)

# English: "the red house"
# Spanish: "la casa roja" (feminine)
```

### Number Agreement

Determiners, nouns, and adjectives must agree in number.

```elixir
# English: "the cats"
# Spanish: "los gatos" (plural)

# English: "the big cats"
# Spanish: "los gatos grandes" (plural throughout)
```

### Person Agreement

Subject-verb agreement by grammatical person.

```elixir
# English: "I run"
# Spanish: "Yo corro" (first person singular)

# English: "They run"
# Spanish: "Ellos corren" (third person plural)
```

## Word Order Rules

### SVO vs. SOV

English, Spanish, and Catalan all use Subject-Verb-Object (SVO) order:

```elixir
# English: "The cat eats fish."
# Spanish: "El gato come pescado."
# Catalan: "El gat menja peix."
```

### Adjective Position

**English:** Adjectives before nouns
```
"the red car"
"the big house"
```

**Spanish/Catalan:** Most adjectives after nouns
```
"el carro rojo" (the car red)
"la casa grande" (the house big)
```

**Exceptions:** Some adjectives stay before nouns
```
"el buen libro" (the good book) - NOT "el libro bueno"
"la primera vez" (the first time) - NOT "la vez primera"
```

### Clitic Placement

**Spanish clitics** (lo, la, me, te, se) attach to verbs:

```elixir
# English: "I see it"
# Spanish: "Lo veo" (clitic before conjugated verb)

# English: "I want to see it"
# Spanish: "Quiero verlo" (clitic after infinitive)
```

## Lexicon Management

### Lexicon Format

Lexicons are Elixir maps organized by POS tag:

```elixir
# priv/translation/lexicons/en_es.exs
%{
  noun: %{
    "cat" => "gato",
    "house" => "casa",
    "book" => "libro"
  },
  verb: %{
    "run" => "correr",
    "eat" => "comer",
    "sleep" => "dormir"
  },
  adj: %{
    "big" => "grande",
    "red" => "rojo",
    "quick" => "rápido"
  },
  det: %{
    "the" => "el",
    "a" => "un",
    "some" => "algunos"
  }
}
```

### Morphological Information

Include gender/number for target language:

```elixir
%{
  noun: %{
    "cat" => %{lemma: "gato", gender: :masculine},
    "house" => %{lemma: "casa", gender: :feminine},
    "dog" => %{lemma: "perro", gender: :masculine}
  }
}
```

### Idiomatic Expressions

Handle multi-word expressions:

```elixir
%{
  idioms: %{
    "kick the bucket" => "estirar la pata",
    "break the ice" => "romper el hielo",
    "piece of cake" => "pan comido"
  }
}
```

### Custom Lexicons

Add domain-specific vocabulary:

```elixir
# priv/translation/lexicons/custom_tech_en_es.exs
%{
  noun: %{
    "widget" => "componente",
    "server" => "servidor",
    "database" => "base de datos"
  },
  verb: %{
    "deploy" => "desplegar",
    "compile" => "compilar",
    "debug" => "depurar"
  }
}
```

Load custom lexicons:
```elixir
LexiconLoader.load(:en, :es, path: "priv/translation/lexicons/custom_tech_en_es.exs")
```

## Supported Language Pairs

### Direct Pairs

- **English ↔ Spanish** - Full bidirectional support
- **English ↔ Catalan** - Full bidirectional support

### Transitive Pairs

- **Spanish ↔ Catalan** - Via English (two-step translation)

```elixir
# Spanish → Catalan (via English)
{:ok, doc_es} = Nasty.parse("El gato corre.", language: :es)
{:ok, doc_en} = Translator.translate(doc_es, :en)
{:ok, doc_ca} = Translator.translate(doc_en, :ca)
{:ok, text_ca} = Nasty.render(doc_ca)
# => "El gat corre."
```

## Customization

### Extending Lexicons

1. Edit lexicon files in `priv/translation/lexicons/`
2. Add new entries maintaining the POS structure
3. Reload lexicons: `LexiconLoader.reload(:en, :es)`

### Custom Agreement Rules

Extend `Nasty.Translation.Agreement`:

```elixir
defmodule MyApp.CustomAgreement do
  def apply_custom_rule(tokens, language) do
    # Custom agreement logic
    tokens
  end
end
```

### Custom Word Order Rules

Extend `Nasty.Translation.WordOrder`:

```elixir
defmodule MyApp.CustomWordOrder do
  def apply_custom_order(phrase, language) do
    # Custom word order logic
    phrase
  end
end
```

## Best Practices

### 1. Sentence-Level Translation

Translate sentence by sentence for best results:

```elixir
sentences = String.split(text, ~r/[.!?]+/)

translated = Enum.map(sentences, fn sent ->
  {:ok, doc} = Nasty.parse(sent, language: :en)
  {:ok, translated} = Translator.translate(doc, :es)
  {:ok, text} = Nasty.render(translated)
  text
end)
|> Enum.join(". ")
```

### 2. Review Idiomatic Expressions

Idiomatic expressions may not translate literally:

```elixir
# "It's raining cats and dogs"
# Literal: "Está lloviendo gatos y perros" ❌
# Idiomatic: "Está lloviendo a cántaros" ✓
```

### 3. Extend Lexicons for Domain Text

For technical/specialized text, add domain vocabulary:

```elixir
# Add medical, legal, technical terms
# to custom lexicon files
```

### 4. Use for Formal/Technical Text

Best for:
- Technical documentation
- Formal correspondence
- News articles
- Academic text

Less suitable for:
- Poetry
- Idiomatic speech
- Creative writing

### 5. Verify Grammatical Gender

Some nouns have unexpected gender:

```elixir
# "problem" → "problema" (masculine in Spanish!)
# "hand" → "mano" (feminine)
```

Check lexicons and adjust if needed.

## Limitations

### Current Limitations

1. **Idiomatic Expressions**
   - May translate literally rather than idiomatically
   - Solution: Add idiom mappings to lexicons

2. **Complex Verb Tenses**
   - Some tense combinations may not map perfectly
   - Solution: Manual review for complex tenses

3. **Cultural Context**
   - Cultural references not adapted
   - Solution: Add context-aware transformations

4. **Ambiguous Words**
   - First lexicon entry used for ambiguous words
   - Solution: Add context-aware lexicon lookup

5. **Limited Language Pairs**
   - Currently English, Spanish, Catalan only
   - Solution: Add more language implementations

### Workarounds

**For idiomatic text:**
```elixir
# Pre-process idioms before translation
text = String.replace(text, "kick the bucket", "die")
```

**For ambiguous words:**
```elixir
# Use context or manual disambiguation
# "bank" (financial) vs "bank" (river)
```

**For complex grammar:**
```elixir
# Simplify sentence structure before translation
# "Having been running..." → "He ran..."
```

## Future Enhancements

- Neural translation integration
- Context-aware lexicon selection
- Multi-sentence context for pronouns
- Statistical phrase translation
- User feedback learning
- More language pairs (French, German, etc.)

## See Also

- [API.md](API.md) - Translation API reference
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [USER_GUIDE.md](USER_GUIDE.md) - User guide with examples
- [CROSS_LINGUAL.md](CROSS_LINGUAL.md) - Cross-lingual transfer learning
