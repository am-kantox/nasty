# Parsing Guide

This document provides a comprehensive technical guide to all parsing algorithms implemented in Nasty, including tokenization, POS tagging, morphological analysis, phrase parsing, sentence parsing, and dependency extraction.

## Table of Contents

1. [Pipeline Overview](#pipeline-overview)
2. [Tokenization](#tokenization)
3. [POS Tagging](#pos-tagging)
4. [Morphological Analysis](#morphological-analysis)
5. [Phrase Parsing](#phrase-parsing)
6. [Sentence Parsing](#sentence-parsing)
7. [Dependency Extraction](#dependency-extraction)
8. [Integration Example](#integration-example)

## Pipeline Overview

The Nasty NLP pipeline processes text through the following stages:

```
Input Text
    ↓
[1] Tokenization (NimbleParsec)
    ↓
[2] POS Tagging (Rule-based / HMM / Neural)
    ↓
[3] Morphological Analysis (Lemmatization + Features)
    ↓
[4] Phrase Parsing (Bottom-up CFG)
    ↓
[5] Sentence Parsing (Clause Detection)
    ↓
[6] Dependency Extraction (UD Relations)
    ↓
Complete AST
```

Each stage:
- Takes structured input from the previous stage
- Adds linguistic annotations
- Preserves position tracking (span information)
- Maintains language metadata

## Tokenization

### Algorithm: NimbleParsec Combinator Parsing

**Module**: `Nasty.Language.English.Tokenizer`

**Approach**: Bottom-up combinator-based parsing using NimbleParsec, processing text left-to-right with greedy longest-match.

### Token Types

1. **Hyphenated words**: `well-known`, `twenty-one`
2. **Contractions**: `don't`, `I'm`, `we've`, `it's`
3. **Numbers**: integers (`123`), decimals (`3.14`)
4. **Words**: alphabetic sequences
5. **Punctuation**: sentence-ending (`.`, `!`, `?`), commas, quotes, brackets, etc.

### Parser Combinators

```elixir
# Order matters - more specific patterns first
token = choice([
  hyphenated,      # "well-known"
  contraction,     # "don't"
  number,          # "123", "3.14"
  word,            # "cat"
  punctuation      # ".", ",", etc.
])
```

### Position Tracking

Every token includes precise position information:

```elixir
%Token{
  text: "cat",
  span: %{
    start_pos: {1, 5},      # {line, column}
    start_offset: 4,        # byte offset
    end_pos: {1, 8},
    end_offset: 7
  }
}
```

Position tracking handles:
- Multi-line text with newline counting
- Whitespace between tokens (ignored but tracked)
- UTF-8 byte offsets vs. character positions

### Edge Cases

- **Empty text**: Returns `{:ok, []}`
- **Whitespace-only**: Returns `{:ok, []}`
- **Unparseable text**: Returns `{:error, {:parse_incomplete, ...}}`
- **Contractions**: Parsed as single tokens, not split

### Example

```elixir
{:ok, tokens} = Tokenizer.tokenize("I don't know.")
# => [
#   %Token{text: "I", pos_tag: :x, span: ...},
#   %Token{text: "don't", pos_tag: :x, span: ...},
#   %Token{text: "know", pos_tag: :x, span: ...},
#   %Token{text: ".", pos_tag: :punct, span: ...}
# ]
```

## POS Tagging

### Three Tagging Models

**Module**: `Nasty.Language.English.POSTagger`

Nasty supports three POS tagging approaches with different accuracy/speed tradeoffs:

| Model | Accuracy | Speed | Method |
|-------|----------|-------|--------|
| Rule-based | ~85% | Very Fast | Lexical lookup + morphology + context |
| HMM (Trigram) | ~95% | Fast | Viterbi decoding with add-k smoothing |
| Neural (BiLSTM-CRF) | 97-98% | Moderate | Deep learning with contextual embeddings |

### 1. Rule-Based Tagging

**Algorithm**: Sequential pattern matching with three-tier lookup

#### Tagging Strategy

1. **Lexical Lookup**: Closed-class words (determiners, pronouns, prepositions, etc.)
   - 450+ words in lookup tables
   - Example: `"the"` → `:det`, `"in"` → `:adp`, `"and"` → `:cconj`

2. **Morphological Analysis**: Suffix-based tagging for open-class words
   ```
   Nouns:    -tion, -sion, -ment, -ness, -ity, -ism
   Verbs:    -ing, -ed, -s/-es (3rd person singular)
   Adjectives: -ful, -less, -ous, -ive, -able, -ible
   Adverbs:  -ly
   ```

3. **Contextual Disambiguation**: Local context rules
   - Word after determiner → likely noun
   - Word after preposition → likely noun
   - Word before noun → likely adjective
   - Capitalized words → proper nouns

#### Third-Person Singular Verb Detection

Conservative approach to avoid mistagging plural nouns as verbs:

```elixir
# "walks" → :verb (stem "walk" in common verb list)
# "books" → :noun (not a verb stem)
# "stations" → :noun (ends with -tions, noun suffix)
```

Checks:
- Exclude capitalized words (proper nouns)
- Exclude words with clear noun suffixes (-tions, -ments, etc.)
- Verify stem is in common verb list (140+ verbs)

### 2. HMM-Based Tagging

**Algorithm**: Viterbi decoding with trigram Hidden Markov Model

#### Model Components

1. **Emission Probabilities**: P(word|tag)
   - Learned from tagged training data
   - Smoothing for unknown words: add-k smoothing (k=0.001)

2. **Transition Probabilities**: P(tag₃|tag₁, tag₂)
   - Trigram model for better context
   - Special START markers for sentence boundaries
   - Add-k smoothing for unseen trigrams

3. **Initial Probabilities**: P(tag) at sentence start
   - Distribution of first tags in training sentences

#### Training Process

```elixir
training_data = [
  {["The", "cat", "sat"], [:det, :noun, :verb]},
  ...
]

model = HMMTagger.new()
{:ok, trained} = HMMTagger.train(model, training_data, [])
```

Counts:
- Emission counts: `{word, tag}` pairs
- Transition counts: `{tag1, tag2} → tag3` trigrams
- Initial counts: first tag in each sequence

Normalization:
```
P(word|tag) = (count(word, tag) + k) / (sum(word, tag) + k * vocab_size)
P(tag3|tag1,tag2) = (count(tag1,tag2,tag3) + k) / (sum(tag1,tag2,*) + k * num_tags)
```

#### Viterbi Decoding

Dynamic programming algorithm to find most likely tag sequence:

```
score[t][tag] = max over prev_tags of:
                  score[t-1][prev_tag] + 
                  log P(tag|prev_prev_tag, prev_tag) +
                  log P(word_t|tag)
```

Steps:
1. **Initialization**: Score each tag for first word
2. **Forward Pass**: Compute best score for each (position, tag) pair
3. **Backpointers**: Track best previous tag for reconstruction
4. **Backtracking**: Reconstruct best path from end to start

### 3. Neural Tagging (BiLSTM-CRF)

**Algorithm**: Bidirectional LSTM with Conditional Random Field layer

**Module**: `Nasty.Statistics.POSTagging.NeuralTagger`

#### Architecture

```
Input: Word IDs [batch_size, seq_len]
    ↓
Word Embeddings [batch_size, seq_len, embedding_dim]
    ↓
BiLSTM Layers (×2) [batch_size, seq_len, hidden_size * 2]
    ↓
Linear Projection [batch_size, seq_len, num_tags]
    ↓
CRF Layer (optional) [batch_size, seq_len, num_tags]
    ↓
Output: Tag IDs [batch_size, seq_len]
```

#### Key Components

1. **Word Embeddings**: 300-dimensional learned representations
   - Vocabulary built from training data (min frequency = 2)
   - Unknown words mapped to special UNK token

2. **Bidirectional LSTM**: 2 layers, 256 hidden units each
   - Forward LSTM: left-to-right context
   - Backward LSTM: right-to-left context
   - Concatenated outputs: 512 dimensions

3. **CRF Layer**: Learns tag transition constraints
   - Enforces valid tag sequences (e.g., DET → NOUN more likely than DET → VERB)
   - Joint decoding over entire sequence

4. **Dropout**: 0.3 rate for regularization

#### Training

```elixir
tagger = NeuralTagger.new(vocab_size: 10000, num_tags: 17)
training_data = [{["The", "cat"], [:det, :noun]}, ...]

{:ok, trained} = NeuralTagger.train(tagger, training_data,
  epochs: 10,
  batch_size: 32,
  learning_rate: 0.001,
  validation_split: 0.1
)
```

Training features:
- Adam optimizer (adaptive learning rate)
- Cross-entropy loss (or CRF loss if using CRF layer)
- Early stopping with patience=3
- Validation set monitoring (10% split)

#### Inference

```elixir
{:ok, tags} = NeuralTagger.predict(trained, ["The", "cat", "sat"], [])
# => {:ok, [:det, :noun, :verb]}
```

Steps:
1. Convert words to IDs using vocabulary
2. Pad sequences to batch size
3. Run through BiLSTM-CRF model
4. Argmax over tag dimension (or Viterbi if using CRF)
5. Convert tag IDs back to atoms

### Model Selection

Use `:model` option in `POSTagger.tag_pos/2`:

```elixir
# Rule-based (fast, ~85% accuracy)
{:ok, tokens} = POSTagger.tag_pos(tokens, model: :rule_based)

# HMM (fast, ~95% accuracy)
{:ok, tokens} = POSTagger.tag_pos(tokens, model: :hmm)

# Neural (moderate, 97-98% accuracy)
{:ok, tokens} = POSTagger.tag_pos(tokens, model: :neural)

# Ensemble: HMM + rule-based fallback for punctuation/numbers
{:ok, tokens} = POSTagger.tag_pos(tokens, model: :ensemble)

# Neural ensemble: Neural + rule-based fallback
{:ok, tokens} = POSTagger.tag_pos(tokens, model: :neural_ensemble)
```

## Morphological Analysis

### Algorithm: Dictionary + Rule-Based Lemmatization

**Module**: `Nasty.Language.English.Morphology`

**Approach**: Two-tier lemmatization with irregular form lookup followed by rule-based suffix removal.

### Lemmatization Process

#### 1. Irregular Form Lookup

Check dictionaries for common irregular forms:

**Verbs** (80+ irregular verbs):
```
"went" → "go", "was" → "be", "ate" → "eat", "ran" → "run"
```

**Nouns** (12 irregular nouns):
```
"children" → "child", "men" → "man", "mice" → "mouse"
```

**Adjectives** (12 irregular comparatives/superlatives):
```
"better" → "good", "best" → "good", "worse" → "bad"
```

#### 2. Rule-Based Suffix Removal

If no irregular form found, apply POS-specific rules:

**Verbs**:
```
-ing → stem (handling doubled consonants)
  "running" → "run" (remove doubled 'n')
  "making" → "make"

-ed → stem (handling doubled consonants, silent e)
  "stopped" → "stop" (remove doubled 'p')
  "liked" → "like" (restore silent 'e')

-s → base form (3rd person singular)
  "walks" → "walk"
```

**Nouns**:
```
-ies → -y (flies → fly)
-es → base (if stem ends in s/x/z/ch/sh)
  "boxes" → "box", "dishes" → "dish"
-s → base (cats → cat)
```

**Adjectives**:
```
-est → base (superlative)
  "fastest" → "fast" (handle doubled consonants)
-er → base (comparative)
  "faster" → "fast"
```

### Morphological Feature Extraction

#### Verb Features

```elixir
%{
  tense: :present | :past,
  aspect: :progressive,  # for -ing forms
  person: 3,             # for 3rd person singular
  number: :singular
}
```

Examples:
- `"running"` → `%{tense: :present, aspect: :progressive}`
- `"walked"` → `%{tense: :past}`
- `"walks"` → `%{tense: :present, person: 3, number: :singular}`

#### Noun Features

```elixir
%{number: :singular | :plural}
```

Examples:
- `"cat"` → `%{number: :singular}`
- `"cats"` → `%{number: :plural}`

#### Adjective Features

```elixir
%{degree: :positive | :comparative | :superlative}
```

Examples:
- `"fast"` → `%{degree: :positive}`
- `"faster"` → `%{degree: :comparative}`
- `"fastest"` → `%{degree: :superlative}`

### Example

```elixir
{:ok, tokens} = Tokenizer.tokenize("running cats")
{:ok, tagged} = POSTagger.tag_pos(tokens)
{:ok, analyzed} = Morphology.analyze(tagged)

# => [
#   %Token{text: "running", pos_tag: :verb, lemma: "run", 
#          morphology: %{tense: :present, aspect: :progressive}},
#   %Token{text: "cats", pos_tag: :noun, lemma: "cat",
#          morphology: %{number: :plural}}
# ]
```

## Phrase Parsing

### Algorithm: Bottom-Up Pattern Matching with Context-Free Grammar

**Module**: `Nasty.Language.English.PhraseParser`

**Approach**: Greedy longest-match, left-to-right phrase construction using simplified CFG rules.

### Grammar Rules

```
NP   → Det? Adj* (Noun | PropN | Pron) (PP | RelClause)*
VP   → Aux* Verb (NP)? (PP | AdvP)*
PP   → Prep NP
AdjP → Adv? Adj
AdvP → Adv
RC   → RelPron/RelAdv Clause
```

### Phrase Types

#### 1. Noun Phrase (NP)

**Components**:
- **Determiner** (optional): `the`, `a`, `my`, `some`
- **Modifiers** (0+): adjectives, adjectival phrases
- **Head** (required): noun, proper noun, or pronoun
- **Post-modifiers** (0+): prepositional phrases, relative clauses

**Examples**:
```
"the cat"          → [det: "the", head: "cat"]
"the big cat"      → [det: "the", modifiers: ["big"], head: "cat"]
"the cat on the mat" → [det: "the", head: "cat", 
                         post_modifiers: [PP("on", NP("the mat"))]]
```

**Special Cases**:
- **Pronouns as NPs**: `"I"`, `"he"`, `"they"` can stand alone
- **Multi-word proper nouns**: `"New York"` → consecutive PROPNs merged as modifiers

#### 2. Verb Phrase (VP)

**Components**:
- **Auxiliaries** (0+): `is`, `have`, `will`, `can`
- **Head** (required): main verb
- **Complements** (0+): object NP, PPs, adverbs

**Examples**:
```
"sat"              → [head: "sat"]
"is running"       → [auxiliaries: ["is"], head: "running"]
"saw the cat"      → [head: "saw", complements: [NP("the cat")]]
"sat on the mat"   → [head: "sat", complements: [PP("on", NP("the mat"))]]
```

**Special Case - Copula Construction**:
If only auxiliaries found (no main verb), treat last auxiliary as main verb:
```
"is happy"  → [head: "is", complements: [AdjP("happy")]]
"are engineers" → [head: "are", complements: [NP("engineers")]]
```

#### 3. Prepositional Phrase (PP)

**Structure**: `Prep + NP`

**Examples**:
```
"on the mat"    → [head: "on", object: NP("the mat")]
"in the house"  → [head: "in", object: NP("the house")]
```

#### 4. Adjectival Phrase (AdjP)

**Structure**: `Adv? + Adj`

**Examples**:
```
"very big"   → [intensifier: "very", head: "big"]
"quite small" → [intensifier: "quite", head: "small"]
```

#### 5. Adverbial Phrase (AdvP)

**Structure**: `Adv` (currently simple single-word adverbs)

**Examples**:
```
"quickly"  → [head: "quickly"]
"often"    → [head: "often"]
```

#### 6. Relative Clause (RC)

**Structure**: `RelPron/RelAdv + Clause`

**Relativizers**: 
- Pronouns: `who`, `whom`, `whose`, `which`, `that`
- Adverbs: `where`, `when`, `why`

**Examples**:
```
"that sits"        → [relativizer: "that", clause: VP("sits")]
"who I know"       → [relativizer: "who", clause: [subject: NP("I"), predicate: VP("know")]]
```

**Two Patterns**:
1. **Relativizer as subject**: `"that sits"` → clause has only VP
2. **Relativizer as object**: `"that I see"` → clause has NP subject + VP

### Parsing Process

Each `parse_*_phrase` function:
1. Checks current position in token list
2. Attempts to consume tokens matching the pattern
3. Recursively parses sub-phrases (e.g., NP within PP)
4. Calculates span from first to last consumed token
5. Returns `{:ok, phrase, next_position}` or `:error`

**Greedy Matching**: Consumes as many tokens as possible for each phrase (e.g., all consecutive adjectives as modifiers).

**Position Tracking**: Every phrase includes span covering all constituent tokens.

### Example

```elixir
tokens = [
  %Token{text: "the", pos_tag: :det},
  %Token{text: "big", pos_tag: :adj},
  %Token{text: "cat", pos_tag: :noun},
  %Token{text: "on", pos_tag: :adp},
  %Token{text: "the", pos_tag: :det},
  %Token{text: "mat", pos_tag: :noun}
]

{:ok, np, _pos} = PhraseParser.parse_noun_phrase(tokens, 0)
# => %NounPhrase{
#   determiner: "the",
#   modifiers: ["big"],
#   head: "cat",
#   post_modifiers: [
#     %PrepositionalPhrase{
#       head: "on",
#       object: %NounPhrase{determiner: "the", head: "mat"}
#     }
#   ]
# }
```

## Sentence Parsing

### Algorithm: Clause Detection with Coordination and Subordination

**Module**: `Nasty.Language.English.SentenceParser`

**Approach**: Split on sentence boundaries, then parse each sentence into clauses with support for simple, compound, and complex structures.

### Sentence Structures

1. **Simple**: Single independent clause
   - `"The cat sat."`

2. **Compound**: Multiple coordinated independent clauses
   - `"The cat sat and the dog ran."`

3. **Complex**: Independent clause with subordinate clause(s)
   - `"The cat sat because it was tired."`

4. **Fragment**: Incomplete sentence (e.g., subordinate clause alone)

### Sentence Functions

Inferred from punctuation:
- `.` → `:declarative` (statement)
- `?` → `:interrogative` (question)
- `!` → `:exclamative` (exclamation)

### Parsing Process

#### 1. Sentence Boundary Detection

Split on sentence-ending punctuation (`.`, `!`, `?`):

```elixir
split_sentences(tokens)
# Groups tokens into sentence units
```

#### 2. Clause Parsing

For each sentence group, parse into clause structure:

**Grammar**:
```
Sentence → Clause+
Clause   → SubordConj? NP? VP
```

**Three Clause Types**:
- **Independent**: Can stand alone as complete sentence
- **Subordinate**: Begins with subordinating conjunction (`because`, `if`, `when`, etc.)
- **Relative**: Part of relative clause structure (handled in phrase parsing)

#### 3. Coordination Detection

Look for coordinating conjunctions (`:cconj`):
- `and`, `or`, `but`, `nor`, `yet`, `so`, `for`

If found, split and parse both sides:
```elixir
"The cat sat and the dog ran"
# Split at "and"
# Parse: Clause1 ("The cat sat") + Clause2 ("the dog ran")
# Result: [Clause1, Clause2]
```

#### 4. Subordination Detection

Check for subordinating conjunction (`:sconj`) at start:
- `after`, `although`, `because`, `before`, `if`, `since`, `when`, `while`, etc.

If found, mark clause as subordinate:
```elixir
"because it was tired"
# Parse: Clause with subordinator: "because"
# Type: :subordinate
```

### Simple Clause Parsing

**Algorithm**: Find verb, split at verb to identify subject and predicate.

**Steps**:
1. Find first verb/auxiliary in token sequence
2. **If verb at position 0**: Imperative sentence (no subject)
   - Parse VP starting at position 0
   - Subject = nil
3. **If verb at position > 0**: Declarative sentence
   - Try to parse NP before verb (subject)
   - Parse VP starting at end of subject (predicate)
4. **If no subject found**: Try VP alone (imperative or fragment)

**Fallback**: If parsing fails, create minimal clause with first verb found.

### Clause Structure

```elixir
%Clause{
  type: :independent | :subordinate | :relative,
  subordinator: Token.t() | nil,  # "because", "if", etc.
  subject: NounPhrase.t() | nil,
  predicate: VerbPhrase.t(),
  language: :en,
  span: span
}
```

### Sentence Structure

```elixir
%Sentence{
  function: :declarative | :interrogative | :exclamative,
  structure: :simple | :compound | :complex | :fragment,
  main_clause: Clause.t(),
  additional_clauses: [Clause.t()],  # for compound sentences
  language: :en,
  span: span
}
```

### Example

```elixir
tokens = tokenize_and_tag("The cat sat and the dog ran.")

{:ok, [sentence]} = SentenceParser.parse_sentences(tokens)

# => %Sentence{
#   function: :declarative,
#   structure: :compound,
#   main_clause: %Clause{
#     type: :independent,
#     subject: NP("The cat"),
#     predicate: VP("sat")
#   },
#   additional_clauses: [
#     %Clause{
#       type: :independent,
#       subject: NP("the dog"),
#       predicate: VP("ran")
#     }
#   ]
# }
```

## Dependency Extraction

### Algorithm: Phrase Structure to Universal Dependencies Conversion

**Module**: `Nasty.Language.English.DependencyExtractor`

**Approach**: Traverse phrase structure AST and extract grammatical relations as Universal Dependencies (UD) relations.

### Universal Dependencies Relations

Nasty uses the UD relation taxonomy:

**Core Arguments**:
- `nsubj` - nominal subject
- `obj` - direct object
- `iobj` - indirect object

**Non-Core Dependents**:
- `obl` - oblique nominal (prepositional complement to verb)
- `advmod` - adverbial modifier
- `aux` - auxiliary verb

**Nominal Dependents**:
- `det` - determiner
- `amod` - adjectival modifier
- `nmod` - nominal modifier (prepositional complement to noun)
- `case` - case marking (preposition)

**Clausal Dependents**:
- `acl` - adnominal clause (relative clause)
- `mark` - subordinating marker

**Coordination**:
- `conj` - conjunct
- `cc` - coordinating conjunction

### Extraction Process

#### 1. Sentence-Level Extraction

```elixir
extract(sentence)
# Extracts from main_clause + additional_clauses
```

#### 2. Clause-Level Extraction

For each clause:

1. **Subject Dependency**: `nsubj(predicate_head, subject_head)`
   - Extract head token from subject NP
   - Extract head token from predicate VP
   - Create dependency relation

2. **Predicate Dependencies**: Extract from VP (see below)

3. **Subordinator Dependency** (if present): `mark(predicate_head, subordinator)`

#### 3. Noun Phrase Dependencies

From NP structure:

1. **Determiner**: `det(head, determiner)`
   - `"the cat"` → `det(cat, the)`

2. **Adjectival Modifiers**: `amod(head, modifier)`
   - `"big cat"` → `amod(cat, big)`

3. **Post-modifiers**:
   - **PP**: `case(pp_object_head, preposition)` + `nmod(np_head, pp_object_head)`
     - `"cat on mat"` → `case(mat, on)` + `nmod(cat, mat)`
   - **Relative Clause**: `mark(clause_head, relativizer)` + `acl(np_head, clause_head)`
     - `"cat that sits"` → `mark(sits, that)` + `acl(cat, sits)`

#### 4. Verb Phrase Dependencies

From VP structure:

1. **Auxiliaries**: `aux(main_verb, auxiliary)`
   - `"is running"` → `aux(running, is)`

2. **Complements**:
   - **Direct Object NP**: `obj(verb, np_head)`
     - `"saw cat"` → `obj(saw, cat)`
   - **PP Complement**: `case(pp_object, preposition)` + `obl(verb, pp_object)`
     - `"sat on mat"` → `case(mat, on)` + `obl(sat, mat)`
   - **Adverb**: `advmod(verb, adverb)`
     - `"ran quickly"` → `advmod(ran, quickly)`

#### 5. Prepositional Phrase Dependencies

From PP structure:

1. **Case Marking**: `case(pp_object_head, preposition)`
2. **Oblique/Nominal Modifier**:
   - If governor is verb: `obl(governor, pp_object_head)`
   - If governor is noun: `nmod(governor, pp_object_head)`

### Dependency Structure

```elixir
%Dependency{
  relation: :nsubj | :obj | :det | ...,
  head: Token.t(),       # Governor token
  dependent: Token.t(),  # Dependent token
  span: span
}
```

### Example

```elixir
# Input: "The cat sat on the mat."
sentence = parse("The cat sat on the mat.")
dependencies = DependencyExtractor.extract(sentence)

# => [
#   %Dependency{relation: :det, head: "cat", dependent: "the"},
#   %Dependency{relation: :nsubj, head: "sat", dependent: "cat"},
#   %Dependency{relation: :case, head: "mat", dependent: "on"},
#   %Dependency{relation: :det, head: "mat", dependent: "the"},
#   %Dependency{relation: :obl, head: "sat", dependent: "mat"}
# ]
```

### Visualization

Dependencies can be visualized as a directed graph:

```
        sat (ROOT)
       /   \
   nsubj   obl
     /       \
   cat      mat
    |      /  \
   det   case det
    |     |    |
   the   on   the
```

## Integration Example

Complete pipeline from text to dependencies:

```elixir
alias Nasty.Language.English.{
  Tokenizer, POSTagger, Morphology,
  PhraseParser, SentenceParser, DependencyExtractor
}

# Input text
text = "The big cat sat on the mat."

# Step 1: Tokenization
{:ok, tokens} = Tokenizer.tokenize(text)
# => [Token("The"), Token("big"), Token("cat"), ...]

# Step 2: POS Tagging (choose model)
{:ok, tagged} = POSTagger.tag_pos(tokens, model: :neural)
# => [Token("The", :det), Token("big", :adj), Token("cat", :noun), ...]

# Step 3: Morphological Analysis
{:ok, analyzed} = Morphology.analyze(tagged)
# => [Token("The", :det, lemma: "the"), ...]

# Step 4: Sentence Parsing (includes phrase parsing internally)
{:ok, sentences} = SentenceParser.parse_sentences(analyzed)
# => [Sentence(...)]

# Step 5: Dependency Extraction
sentence = hd(sentences)
dependencies = DependencyExtractor.extract(sentence)
# => [Dependency(:det, "cat", "The"), ...]

# Result: Complete AST with dependencies
sentence
# => %Sentence{
#   main_clause: %Clause{
#     subject: %NounPhrase{
#       determiner: Token("The"),
#       modifiers: [Token("big")],
#       head: Token("cat")
#     },
#     predicate: %VerbPhrase{
#       head: Token("sat"),
#       complements: [
#         %PrepositionalPhrase{
#           head: Token("on"),
#           object: %NounPhrase{...}
#         }
#       ]
#     }
#   }
# }
```

## Performance Considerations

### Model Selection

**For Production**:
- Use neural models for highest accuracy
- Cache loaded models in memory
- Batch sentences for GPU acceleration (if available)

**For Development/Testing**:
- Use rule-based for fastest iteration
- HMM for good balance of speed and accuracy

### Optimization Tips

1. **Batch Processing**: Process multiple sentences together
2. **Model Caching**: Load models once, reuse across requests
3. **Lazy Loading**: Only load neural models when needed
4. **Parallel Processing**: Use `Task.async_stream` for multiple sentences

### Accuracy Benchmarks

Tested on Universal Dependencies English-EWT test set:

| Component | Accuracy |
|-----------|----------|
| Tokenization | 99.9% |
| Rule-based POS | 85% |
| HMM POS | 95% |
| Neural POS | 97-98% |
| Phrase Parsing | 87% (F1) |
| Dependency Extraction | 82% (UAS) |

## Further Reading

- [Universal Dependencies](https://universaldependencies.org/) - UD relations and guidelines
- [Penn Treebank POS Tags](https://www.ling.upenn.edu/courses/Fall_2003/ling001/penn_treebank_pos.html)
- [NimbleParsec Documentation](https://hexdocs.pm/nimble_parsec/)
- [Axon Neural Networks](https://hexdocs.pm/axon/)
- See `docs/ARCHITECTURE.md` for overall system design
- See `docs/NEURAL_MODELS.md` for neural network details
