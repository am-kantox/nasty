# Grammar Resources

This document describes the grammar resource system in Nasty, which externalizes lexicons and grammar rules to separate files for easy modification and multilingual support.

## Overview

Grammar resources are stored in `priv/languages/{language_code}/` and include:

- **Lexicons**: Word lists for closed-class words (determiners, pronouns, etc.)
- **Grammar rules**: Context-Free Grammar (CFG) rules for phrase structure
- **Other resources**: Irregular verb forms, stop words, etc.

## Directory Structure

```
priv/languages/
├── en/                      # English resources
│   ├── lexicons/           # Word lists
│   │   ├── determiners.exs
│   │   ├── pronouns.exs
│   │   ├── prepositions.exs
│   │   ├── conjunctions_coord.exs
│   │   ├── conjunctions_sub.exs
│   │   ├── auxiliaries.exs
│   │   ├── adverbs.exs
│   │   ├── particles.exs
│   │   ├── interjections.exs
│   │   ├── common_verbs.exs
│   │   ├── common_adjectives.exs
│   │   ├── irregular_verbs.txt
│   │   ├── irregular_nouns.txt
│   │   └── stop_words.txt
│   └── grammars/           # Grammar rules
│       ├── phrase_rules.ex
│       └── dependency_rules.ex
├── es/                      # Spanish resources
│   └── ...
└── ca/                      # Catalan resources
    └── ...
```

## Lexicon File Format

Lexicon files use Elixir term format (`.exs`) and evaluate to a list of strings using the `~w()` sigil.

### Example: `determiners.exs`

```elixir
# English Determiners
# Articles, demonstratives, possessives, quantifiers

~w(
  the a an
  this that these those
  my your his her its our their
  some any no every each either neither
  much many more most less least few several all both half
  whose
)
```

### Lexicon Categories

#### Closed-Class Words (Complete Lists)

- **Determiners** (`determiners.exs`) - Articles, demonstratives, possessives, quantifiers
- **Pronouns** (`pronouns.exs`) - Personal, possessive, reflexive, demonstrative, interrogative
- **Prepositions** (`prepositions.exs`) - Spatial, temporal, logical relations
- **Coordinating Conjunctions** (`conjunctions_coord.exs`) - FANBOYS (for, and, nor, but, or, yet, so)
- **Subordinating Conjunctions** (`conjunctions_sub.exs`) - after, although, because, if, when, etc.
- **Auxiliaries** (`auxiliaries.exs`) - be, have, do, modals (will, can, should, etc.)
- **Particles** (`particles.exs`) - Phrasal verb particles (up, down, out, etc.)
- **Interjections** (`interjections.exs`) - oh, wow, hey, etc.

#### Open-Class Words (Common Examples)

- **Common Verbs** (`common_verbs.exs`) - Frequently used verbs with all inflections
- **Common Adjectives** (`common_adjectives.exs`) - Frequently used qualitative and relational adjectives

### Verb Inflections

The `common_verbs.exs` file includes all inflected forms:

```elixir
~w(
  go went gone going goes
  come came coming comes
  see saw seen seeing sees
  ...
)
```

This ensures that verbs are recognized in all their forms during POS tagging.

## Loading Lexicons

### In Code

Use the `LexiconLoader` module to load lexicons:

```elixir
alias Nasty.Language.Resources.LexiconLoader

# Load a lexicon
determiners = LexiconLoader.load(:en, :determiners)

# Check if word is in lexicon
LexiconLoader.in_lexicon?(:en, :determiners, "the")  # => true

# List all available lexicons
LexiconLoader.list_lexicons(:en)
```

### At Compile Time

For performance, load lexicons at compile time using module attributes:

```elixir
defmodule MyModule do
  alias Nasty.Language.Resources.LexiconLoader

  @determiners LexiconLoader.load(:en, :determiners)
  @pronouns LexiconLoader.load(:en, :pronouns)

  defp determiners, do: @determiners
  defp pronouns, do: @pronouns
end
```

This is how the `POSTagger` module loads lexicons efficiently.

## Grammar Rules

Grammar rules are documented in `grammars/phrase_rules.ex` and follow Context-Free Grammar (CFG) notation.

### Phrase Structure Rules

```elixir
# Noun Phrase
NP → Det? Adj* (Noun | PropN | Pron) PP* RC*

# Verb Phrase
VP → Aux* Verb NP? PP* AdvP*

# Prepositional Phrase
PP → Prep NP

# Adjectival Phrase
AdjP → Adv? Adj

# Adverbial Phrase
AdvP → Adv+
```

### Rule File Format

Grammar rules are defined as Elixir modules returning lists of tuples:

```elixir
defmodule Nasty.Language.English.Grammar.PhraseRules do
  def rules do
    [
      {:np, [
        [:det, :adj, :noun],
        [:det, :noun],
        [:noun],
        [:propn],
        [:pron]
      ]},
      {:vp, [
        [:aux, :verb, :np],
        [:verb, :np],
        [:verb]
      ]},
      # ...
    ]
  end
end
```

Note: Currently, these rules are documentation only. The phrase parser uses procedural pattern matching rather than rule interpretation. Future versions may add a rule-based parser.

## Adding a New Language

To add support for a new language:

1. **Create directory structure**:
   ```bash
   mkdir -p priv/languages/{code}/lexicons
   mkdir -p priv/languages/{code}/grammars
   ```

2. **Create lexicon files**: Translate lexicons from English, adjusting for the language's grammar

3. **Create grammar rules**: Define CFG rules for the language's phrase structure

4. **Implement language module**: Create a module implementing `Nasty.Language.Behaviour`

5. **Register language**: Register in `Nasty.Application`

### Example: Spanish Lexicons

```elixir
# priv/languages/es/lexicons/determiners.exs
~w(
  el la los las
  un una unos unas
  este esta estos estas
  ese esa esos esas
  mi tu su nuestro vuestra
  algún alguna algunos algunas
)
```

## Modifying Lexicons

To add or modify words:

1. Edit the appropriate `.exs` file in `priv/languages/{code}/lexicons/`
2. Recompile the project: `mix compile --force`
3. Run tests to verify: `mix test`

Changes take effect immediately after recompilation since lexicons are loaded at compile time.

## Testing

Lexicon loading is tested in `test/language/resources/lexicon_loader_test.exs`:

```elixir
test "loads determiners lexicon for English" do
  determiners = LexiconLoader.load(:en, :determiners)
  
  assert is_list(determiners)
  assert "the" in determiners
  assert "a" in determiners
end
```

## Performance Considerations

- **Compile-time loading**: Lexicons are loaded once during compilation and cached as module attributes
- **No runtime overhead**: Lookups are fast list membership checks
- **Memory usage**: All lexicons are kept in memory (typically < 1MB per language)

## Best Practices

1. **Keep lexicons sorted**: Makes it easier to find and avoid duplicates
2. **Add comments**: Document word categories and usage patterns
3. **Test coverage**: Add tests for new lexicons or grammar rules
4. **Version control**: Commit lexicon changes with descriptive messages
5. **Language consistency**: Follow Universal Dependencies (UD) tag set

## Future Work

- **Rule-based parser**: Implement CFG rule interpreter for phrase parsing
- **Pattern rules**: Add pattern matching rules for specific constructions
- **Morphological rules**: Externalize morphological analysis patterns
- **Statistical models**: Support for statistical grammar models

## References

- [Universal Dependencies](https://universaldependencies.org/) - POS tags and dependency relations
- [docs/languages/ENGLISH_GRAMMAR.md](languages/ENGLISH_GRAMMAR.md) - Formal English grammar specification
- [docs/PARSING_GUIDE.md](PARSING_GUIDE.md) - Parsing algorithm documentation
