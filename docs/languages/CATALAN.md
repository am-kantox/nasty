# Catalan Language Support

Comprehensive Catalan language support for the Nasty NLP library.

## Status

**Implemented (Phases 1-7):**
- Tokenization with Catalan-specific features
- POS tagging with Universal Dependencies tagset
- Morphological analysis and lemmatization
- Grammar resource files (phrase and dependency rules)
- Phrase and sentence parsing (NP, VP, PP, clause detection)
- Dependency extraction (Universal Dependencies relations)
- Named entity recognition (PERSON, LOCATION, ORGANIZATION, DATE, MONEY, PERCENT)

**Pending (Phase 8):**
- Text summarization (stub implementation)
- Coreference resolution
- Semantic role labeling

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
alias Nasty.Language.Catalan

# Complete pipeline
text = "El gat dorm al sofà."
{:ok, tokens} = Catalan.tokenize(text)
{:ok, tagged} = Catalan.tag_pos(tokens)
{:ok, document} = Catalan.parse(tagged)

# Extract entities
alias Nasty.Language.Catalan.EntityRecognizer
{:ok, entities} = EntityRecognizer.recognize(tagged)
# => [%Entity{type: :person, text: "Joan Garcia", ...}]

# Extract dependencies
alias Nasty.Language.Catalan.DependencyExtractor
sentences = document.paragraphs |> Enum.flat_map(& &1.sentences)
deps = Enum.flat_map(sentences, &DependencyExtractor.extract/1)
# => [%Dependency{relation: :nsubj, head: "dorm", dependent: "gat", ...}]

# Individual components
{:ok, tokens} = Catalan.Tokenizer.tokenize("El gat dorm al sofà.")
{:ok, tagged} = Catalan.POSTagger.tag_pos(tokens)
{:ok, analyzed} = Catalan.Morphology.analyze(tagged)

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

## Implementation Details

### Phrase Parser (`lib/language/catalan/phrase_parser.ex` - 334 lines)

- `parse_noun_phrase/2`: Handles quantifiers, determiners, adjectives, and post-modifiers
- `parse_verb_phrase/2`: Processes auxiliaries, main verbs, objects, and complements
- `parse_prep_phrase/2`: Parses preposition + noun phrase structures
- Catalan-specific: Post-nominal adjectives, quantifying adjectives (molt, poc, algun, tot)

### Sentence Parser (`lib/language/catalan/sentence_parser.ex` - 281 lines)

- `parse_sentences/2`: Sentence boundary detection and splitting
- `parse_clause/2`: Subject and predicate extraction
- Catalan subordinators: que, perquè, quan, on, si, encara, mentre, així, doncs, ja
- Coordination: i, o, però, sinó, ni

### Dependency Extractor (`lib/language/catalan/dependency_extractor.ex` - 226 lines)

- Extracts Universal Dependencies relations from parsed structures
- Core relations: nsubj (nominal subject), obj (object), iobj (indirect object)
- Modifiers: det (determiner), amod (adjectival modifier), advmod (adverbial modifier)
- Function words: aux (auxiliary), case (case marking), mark (subordinating conjunction)
- Coordination: cc (coordinating conjunction), conj (conjunct)

### Entity Recognizer (`lib/language/catalan/entity_recognizer.ex` - 285 lines)

- Rule-based NER with 6 entity types
- **PERSON**: Catalan titles (Sr., Sra., Dr., Dra., Don, Donya), capitalized name sequences
- **LOCATION**: Catalan places (Barcelona, Catalunya, València, Girona, Tarragona, Lleida, Andorra)
- **ORGANIZATION**: Indicators (banc, universitat, hospital, ajuntament, govern)
- **DATE**: Catalan months and days (gener, febrer, març, dilluns, dimarts)
- **MONEY**: Euro symbols (€, euros, dòlar, dòlars)
- **PERCENT**: Percentage symbols (%, per cent)
- Confidence scoring: 0.5-0.95 based on pattern strength

## Future Work (Phase 8 and Beyond)

1. **Summarizer**: Extractive and abstractive text summarization
2. **Coreference Resolution**: Link mentions across sentences
3. **Semantic Role Labeling**: Predicate-argument structure
4. **End-to-end Tests**: Integration tests for complete pipeline
5. **Advanced Entity Recognition**: ML-based NER with larger lexicons
6. **Question Answering**: Extractive QA for Catalan texts
7. **Text Classification**: Sentiment analysis, topic classification

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
