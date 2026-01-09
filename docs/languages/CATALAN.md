# Catalan Language Support

Comprehensive Catalan language support for the Nasty NLP library.

## Status

**Implemented (Phases 1-4):**
- Tokenization with Catalan-specific features
- POS tagging with Universal Dependencies tagset
- Morphological analysis and lemmatization
- Grammar resource files (phrase and dependency rules)

**Pending (Phases 5-8):**
- Phrase and sentence parsing (stub implementation)
- Dependency extraction (stub implementation)
- Named entity recognition (stub implementation)
- Text summarization (stub implementation)

## Features

### Tokenization

The Catalan tokenizer handles all language-specific features:

- **Interpunct (l·l)**: Kept as single token
  - Example: `"Col·laborar"` → `["Col·laborar"]`
  - Common in compound words: col·laborar, intel·ligent, il·lusió

- **Apostrophe Contractions**: Separated as distinct tokens
  - Determiners: `l'` (el/la)
  - Prepositions: `d'` (de), `s'` (es/se)
  - Pronouns: `n'` (en), `m'` (me), `t'` (te)
  - Example: `"L'home d'or"` → `["L'", "home", "d'", "or"]`

- **Article Contractions**: Recognized as single tokens
  - `del` = de + el
  - `al` = a + el  
  - `pel` = per + el
  - Example: `"Vaig al mercat"` → `["Vaig", "al", "mercat"]`

- **Diacritics**: Complete support for all 10 Catalan diacritics
  - Vowels: à, è, é, í, ï, ò, ó, ú, ü
  - Consonant: ç (ce trencada)
  - Unicode NFC normalization

### POS Tagging

Rule-based POS tagger using Universal Dependencies tagset:

- **Comprehensive Lexicon**: 300+ word forms
  - Articles, pronouns, prepositions
  - Common verbs, nouns, adjectives, adverbs
  - Function words and particles

- **Verb Conjugations**: All tenses supported
  - Present, preterite, imperfect, future, conditional
  - Subjunctive mood patterns
  - Gerunds and past participles

- **Context-Based Disambiguation**
  - Post-nominal adjective detection
  - Determiner-noun sequences
  - Preposition-noun patterns

### Morphology

Morphological analyzer with lemmatization:

- **Verb Classes**: 3 conjugation classes
  - `-ar` verbs: parlar → parlar, parlant → parlar
  - `-re` verbs: viure → viure, vivint → viure  
  - `-ir` verbs: dormir → dormir, dormint → dormir

- **Irregular Verbs**: Dictionary of 100+ forms
  - ser, estar, haver (auxiliaries)
  - anar, fer, dir, poder, voler (common verbs)
  - tenir, venir, veure (irregulars)

- **Morphological Features**
  - Gender: masculine/feminine
  - Number: singular/plural
  - Tense: present, past, future, conditional, imperfect
  - Mood: indicative, conditional, subjunctive
  - Aspect: progressive, perfective

### Grammar Rules

Externalized grammar files in `priv/languages/ca/grammars/`:

**Phrase Rules** (`phrase_rules.exs`):
- Noun phrases with post-nominal adjectives
- Verb phrases with flexible word order
- Prepositional, adjectival, adverbial phrases
- Relative clause patterns
- Special rules for Catalan-specific features

**Dependency Rules** (`dependency_rules.exs`):
- Universal Dependencies v2 relations
- Core arguments (subject, object, indirect object)
- Non-core dependents (oblique, adverbials)
- Function word relations
- Catalan-specific patterns (clitics, pro-drop)

## Usage

```elixir
# Tokenization
{:ok, tokens} = Nasty.Language.Catalan.Tokenizer.tokenize("El gat dorm al sofà.")

# POS Tagging
{:ok, tagged} = Nasty.Language.Catalan.POSTagger.tag_pos(tokens)

# Morphology
{:ok, analyzed} = Nasty.Language.Catalan.Morphology.analyze(tagged)

# Access lemmas and features
Enum.each(analyzed, fn token ->
  IO.puts("#{token.text} [#{token.pos_tag}] → #{token.lemma}")
end)
```

## Linguistic Features

### Word Order

Catalan allows flexible word order while maintaining SVO as default:

- **SVO** (Subject-Verb-Object): `"El gat menja peix"` (The cat eats fish)
- **VSO** (Verb-Subject-Object): `"Menja el gat peix"` (Eats the cat fish) - emphatic
- **VOS** (Verb-Object-Subject): `"Menja peix el gat"` (Eats fish the cat) - rare

### Pro-Drop

Subject pronouns often omitted when context is clear:

- `"Parla català"` (I/he/she/it speaks Catalan) - subject implicit
- `"Hem anat al mercat"` (We have gone to the market) - subject implicit

### Post-Nominal Adjectives

Descriptive adjectives typically follow nouns:

- `"casa gran"` (big house)
- `"llibre interessant"` (interesting book)
- Exception: `"bon dia"` (good day) - some adjectives precede for emphasis

### Clitic Pronouns

Pronouns can attach to verbs as clitics:

- `"Dona'm el llibre"` (Give me the book) - m' = me
- `"Digue-li la veritat"` (Tell him/her the truth) - li = him/her

## Test Coverage

**74 tests, 0 failures**

- Tokenization: 54 tests
  - Interpunct words
  - Apostrophe and article contractions
  - Diacritics
  - Position tracking
  - Edge cases

- POS Tagging: 20 tests
  - Basic word classes
  - Verb conjugations
  - Catalan-specific features
  - Context-based tagging

## Future Work (Phases 5-8)

1. **Phrase Parser**: Implement using GrammarLoader with phrase_rules.exs
2. **Sentence Parser**: Handle complex sentence structures with subordination
3. **Dependency Extractor**: Extract UD relations using dependency_rules.exs
4. **Entity Recognizer**: Named entity recognition for Catalan
5. **Summarizer**: Extractive and abstractive text summarization
6. **End-to-end Tests**: Integration tests for complete pipeline
7. **Advanced Features**: Semantic role labeling, coreference resolution

## References

- Universal Dependencies Catalan Treebank: [UD_Catalan-AnCora](https://github.com/UniversalDependencies/UD_Catalan-AnCora)
- Catalan Grammar: Institut d'Estudis Catalans
- Linguistic Patterns: Based on Central Catalan (Barcelona dialect)

## Language Code

ISO 639-1: `ca`  
ISO 639-3: `cat`

## Contributing

When enhancing Catalan support:
1. Maintain consistency with Spanish implementation patterns
2. Follow Universal Dependencies standards
3. Document Catalan-specific features
4. Add comprehensive tests for new functionality
5. Update this documentation
