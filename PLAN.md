# Nasty: Natural Abstract Syntax Treey - Implementation Plan

## Vision Statement

Build a foundational, **language-agnostic** NLP library for Elixir that treats natural languages with the same rigor as programming languages: a proper grammatical AST as the core abstraction, enabling bidirectional conversion between natural language and code, and providing a solid foundation for NLP tasks like summarization, analysis, and generation.

**Project Name**: `nasty` (Natural Abstract Syntax Treey)  
**First Implementation**: English (with `@behaviour`-based architecture for multi-language support)

## Core Philosophy

1. **Grammar-First Design**: Natural language grammar as a formal system with well-defined AST nodes
2. **Language-Agnostic Architecture**: Use `@behaviour` for language abstraction (start with English, support Spanish, Catalan, etc. later)
3. **Bidirectional Mapping**: Natural language ↔ Programming language AST conversion
4. **Composable Abstractions**: Build complex NLP operations from simple AST transformations
5. **Parser Combinators**: Use NimbleParsec for efficient, composable grammar rules
6. **Type Safety**: Leverage Elixir's pattern matching and type specs throughout

## Project Architecture

###Phase 0: Language Abstraction Layer (Week 1)

#### 0.1 Core Language Behaviours

Define language-agnostic behaviours that all language implementations must satisfy:

**Nasty.Language.Behaviour**
```elixir
defmodule Nasty.Language.Behaviour do
  @type text :: String.t()
  @type options :: keyword()
  
  @callback tokenize(text, options) :: {:ok, [Nasty.AST.Token.t()]} | {:error, term()}
  @callback tag_pos(tokens :: [Nasty.AST.Token.t()], options) :: 
    {:ok, [Nasty.AST.Token.t()]} | {:error, term()}
  @callback parse(tokens :: [Nasty.AST.Token.t()], options) :: 
    {:ok, Nasty.AST.Document.t()} | {:error, term()}
  @callback render(ast :: Nasty.AST.Node.t(), options) :: 
    {:ok, String.t()} | {:error, term()}
end
```

**Nasty.Language.Parser**
- Generic parsing interface
- Parse pipeline: tokenize → tag → parse → analyze

**Nasty.Language.Renderer**
- AST → Text generation interface
- Language-specific agreement and word order rules

#### 0.2 Language Registry
- Dynamic language loading and registration
- Language detection from text/locale
- Fallback mechanisms

### Phase 1: Universal AST Schema & English Implementation (Week 1-2)

#### 1.1 Core AST Schema Design

Define a comprehensive, linguistically-sound AST applicable across languages:

**Syntactic Layer**
- **Document**: Collection of paragraphs with metadata and language marker
- **Paragraph**: Sequence of sentences with cohesion markers
- **Sentence**: Complete grammatical unit with root clause
- **Clause**: Subject + Predicate structure (independent/dependent)
- **Phrase Nodes**:
  - NounPhrase: Determiner + Modifiers + Head + PostModifiers
  - VerbPhrase: Auxiliaries + MainVerb + Complements + Adverbials
  - PrepositionalPhrase: Preposition + NounPhrase
  - AdjectivalPhrase: Intensifier + Adjective + Complement
  - AdverbialPhrase: Intensifier + Adverb
- **Token**: Word/punctuation with position, lemma, morphology, **language**

**Semantic Layer**
- **Entity**: Named entities (PERSON, ORG, LOC, DATE, etc.)
- **Relation**: Semantic relationships between entities
- **Reference**: Anaphora and coreference chains
- **Event**: Actions, states, processes with participants
- **Modality**: Necessity, possibility, certainty markers
- **Tense/Aspect**: Temporal and aspectual information

**Dependency Layer**
- **Subject**: Grammatical subject (nsubj, csubj)
- **Object**: Direct/indirect objects (dobj, iobj)
- **Modifier**: Adjectives, adverbs, clausal modifiers
- **Complement**: Predicative, clausal complements
- **Coordination**: Conjunctions and coordinated structures

#### 1.2 AST Node Definitions

Implement as Elixir structs with clear contracts and language markers:

```elixir
defmodule Nasty.AST.Node do
  @type position :: {line :: pos_integer, column :: pos_integer}
  @type span :: {start :: position, end :: position}
  @type language :: atom()  # :en, :es, :ca, etc.
end

defmodule Nasty.AST.Token do
  @type t :: %__MODULE__{
    text: String.t(),
    lemma: String.t(),
    pos_tag: atom(),  # :noun, :verb, :adj, etc.
    morphology: map(),  # {number: :singular, tense: :past, ...}
    language: Nasty.AST.Node.language(),
    span: Nasty.AST.Node.span()
  }
  defstruct [:text, :lemma, :pos_tag, :morphology, :language, :span]
end

defmodule Nasty.AST.NounPhrase do
  @type t :: %__MODULE__{
    determiner: Token.t() | nil,
    modifiers: [Token.t() | AdjectivalPhrase.t()],
    head: Token.t(),
    post_modifiers: [PrepositionalPhrase.t() | Clause.t()],
    entity: Entity.t() | nil,
    language: Nasty.AST.Node.language(),
    span: Nasty.AST.Node.span()
  }
  defstruct [:determiner, :modifiers, :head, :post_modifiers, :entity, :language, :span]
end

# ... similar for VerbPhrase, Clause, Sentence, etc.
```

#### 1.3 Grammar Rules Engine

Implement formal grammar rules as Elixir functions:
- **Context-Free Grammar (CFG)** rules for phrase structure
- **Dependency grammar** rules for relationships
- **Transformation rules** for handling variations (active/passive, questions, etc.)
- **Disambiguation strategies** for structural ambiguity

### Phase 2: English Implementation - Lexical Analysis with NimbleParsec (Week 2-3)

#### 2.1 Tokenizer (`Nasty.Language.English.Tokenizer`)

Implement using NimbleParsec combinators:

```elixir
defmodule Nasty.Language.English.Tokenizer do
  import NimbleParsec

  # Whitespace
  whitespace = ascii_string([?\s, ?\t, ?\n, ?\r], min: 1)

  # Punctuation
  sentence_end = choice([string("."), string("!"), string("?")])
  comma = string(",")
  punctuation = choice([sentence_end, comma, string(";"), string(":")])

  # Words (including contractions)
  word = 
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> optional(string("'"))
    |> optional(ascii_string([?a..?z, ?A..?Z], min: 1))
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:word)

  # Tokens
  token = choice([word, punctuation |> unwrap_and_tag(:punct)])

  # Sentence
  sentence = 
    repeat(
      token
      |> optional(ignore(whitespace))
    )
    |> tag(:sentence)

  defparsec :tokenize, repeat(sentence)
end
```

**Features**:
- Sentence boundary detection (handle abbreviations with lookahead)
- Word tokenization with contractions ("don't", "it's")
- Punctuation as separate tokens
- Unicode normalization (pre-processing step)
- Automatic position tracking via NimbleParsec

#### 2.2 Part-of-Speech (POS) Tagger (`Nasty.Language.English.POSTagger`)

Implement tagging using pattern matching on token sequences:

```elixir
defmodule Nasty.Language.English.POSTagger do
  # Rule-based tagging with pattern matching
  def tag_token(word, context) do
    word
    |> String.downcase()
    |> tag_word(context)
  end

  # Determiners
  defp tag_word(word, _) when word in ["the", "a", "an"], do: :det
  
  # Auxiliaries
  defp tag_word(word, _) when word in ["is", "are", "was", "were"], do: :aux
  
  # Common verbs
  defp tag_word(word, :after_noun), do: :verb
  defp tag_word(word, _) when String.ends_with?(word, "ing"), do: :verb
  
  # Default: noun
  defp tag_word(_, _), do: :noun
end
```

**Strategy**:
- **Rule-based approach**: Pattern matching for common structures
- **Context-aware**: Use surrounding tokens for disambiguation
- **Statistical approach** ✅ IMPLEMENTED: Hidden Markov Model with Viterbi decoding (~95% accuracy)
- **Tag set**: Universal Dependencies tags (NOUN, VERB, ADJ, ADV, DET, etc.)

#### 2.3 Morphological Analyzer (`Nasty.Language.English.Morphology`)

Implement using pattern matching and lookup tables:

```elixir
defmodule Nasty.Language.English.Morphology do
  @irregular_verbs %{
    "was" => "be",
    "were" => "be",
    "ran" => "run",
    "went" => "go"
  }

  def lemmatize(word, pos_tag) do
    word_lower = String.downcase(word)
    
    cond do
      Map.has_key?(@irregular_verbs, word_lower) ->
        @irregular_verbs[word_lower]
      
      pos_tag == :verb and String.ends_with?(word_lower, "ing") ->
        String.slice(word_lower, 0..-4//1)
      
      pos_tag == :noun and String.ends_with?(word_lower, "s") ->
        String.slice(word_lower, 0..-2//1)
      
      true ->
        word_lower
    end
  end
  
  def extract_features(word, pos_tag) do
    %{
      number: if(String.ends_with?(word, "s"), do: :plural, else: :singular),
      tense: extract_tense(word, pos_tag)
    }
  end
end
```

**Features**:
- **Lemmatization**: Reduce words to base forms (running → run)
- **Morphological features**: Extract number, tense, person, case, etc.
- **Irregular forms dictionary**: Handle irregular verbs/nouns (loaded from priv/)
- **Compound word splitting**: NimbleParsec rules for hyphenated compounds

### Phase 3: English Implementation - Syntactic Parsing with NimbleParsec (Week 3-5)

#### 3.1 Phrase Structure Parser

Implement using NimbleParsec grammar combinators:

```elixir
defmodule Nasty.Language.English.Grammar do
  import NimbleParsec

  # Terminal symbols (from POS tags)
  det = token_tag(:det) |> unwrap_and_tag(:determiner)
  adj = token_tag(:adj) |> unwrap_and_tag(:adjective)
  noun = token_tag(:noun) |> unwrap_and_tag(:noun)
  verb = token_tag(:verb) |> unwrap_and_tag(:verb)
  prep = token_tag(:prep) |> unwrap_and_tag(:preposition)

  # Noun Phrase: (Det) (Adj)* Noun (PP)*
  noun_phrase = 
    optional(det)
    |> repeat(adj)
    |> concat(noun)
    |> repeat(parsec(:prepositional_phrase))
    |> tag(:noun_phrase)

  # Prepositional Phrase: Prep NP
  prepositional_phrase =
    prep
    |> concat(parsec(:noun_phrase))
    |> tag(:prepositional_phrase)

  # Verb Phrase: (Aux) Verb (NP) (PP)*
  verb_phrase =
    optional(token_tag(:aux))
    |> concat(verb)
    |> optional(parsec(:noun_phrase))
    |> repeat(parsec(:prepositional_phrase))
    |> tag(:verb_phrase)

  # Sentence: NP VP
  sentence =
    parsec(:noun_phrase)
    |> concat(parsec(:verb_phrase))
    |> tag(:sentence)

  defparsec :parse_sentence, sentence
  defparsec :noun_phrase, noun_phrase
  defparsec :prepositional_phrase, prepositional_phrase
  defparsec :verb_phrase, verb_phrase
end
```

**Benefits of NimbleParsec**:
- **Composable grammar rules**: Build complex structures from simple ones
- **Automatic backtracking**: Handles ambiguity naturally
- **Compile-time optimization**: Fast parsing at runtime
- **Built-in position tracking**: For AST span information
- **Recursive parsers**: Use `parsec/1` for recursive grammar rules

**Patterns Handled**:
- Noun phrases with nested modification and relative clauses
- Verb phrases with complex auxiliaries ("has been running")
- Prepositional phrase attachment (with ambiguity resolution)
- Coordination ("and", "or") using `choice` combinator
- Ellipsis through optional combinators

#### 3.2 Dependency Parser

Build dependency relationship extractor as post-processing:

```elixir
defmodule Nasty.Language.English.DependencyParser do
  alias Nasty.AST.{Sentence, NounPhrase, VerbPhrase, Dependency}

  def extract_dependencies(%Sentence{noun_phrase: np, verb_phrase: vp}) do
    [
      %Dependency{relation: :nsubj, head: vp.verb, dependent: np.head},
      extract_object(vp),
      extract_modifiers(np),
      extract_modifiers(vp)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp extract_object(%VerbPhrase{object: obj}) when not is_nil(obj) do
    %Dependency{relation: :dobj, head: verb, dependent: obj.head}
  end
  defp extract_object(_), do: nil
end
```

**Approach**:
- **AST-based extraction**: Walk phrase structure tree from NimbleParsec
- **Rule-based relations**: Map syntactic positions to dependency relations
- **Grammatical relations**: Subject (nsubj), object (dobj), modifiers, etc.
- **Dependency tree**: Built alongside phrase structure

**Future enhancements**:
- Transition-based parsing (Arc-standard algorithm) for complex sentences
- Graph-based parsing (minimum spanning tree) for non-projective dependencies

#### 3.3 Clause and Sentence Parser

Extend NimbleParsec grammar for complex sentences:

```elixir
defmodule Nasty.Language.English.Grammar do
  # Subordinate clause: Conj S
  subordinate_clause =
    token_tag(:conj)  # "because", "although", "if"
    |> concat(parsec(:sentence))
    |> tag(:subordinate_clause)

  # Relative clause: RelPron VP
  relative_clause =
    token_tag(:rel_pron)  # "who", "which", "that"
    |> concat(parsec(:verb_phrase))
    |> tag(:relative_clause)

  # Complex sentence: S (SubordClause)*
  complex_sentence =
    parsec(:simple_sentence)
    |> repeat(subordinate_clause)
    |> tag(:complex_sentence)

  # Coordination: S Conj S
  coordinated_sentence =
    parsec(:simple_sentence)
    |> repeat(
      token_tag(:coord_conj)  # "and", "or", "but"
      |> concat(parsec(:simple_sentence))
    )
    |> tag(:coordinated_sentence)

  # Sentence types (via word order and punctuation)
  interrogative = 
    token_tag(:aux)
    |> concat(parsec(:noun_phrase))
    |> concat(parsec(:verb_phrase))
    |> concat(string("?"))
    |> tag(:interrogative)

  defparsec :complex_sentence, complex_sentence
end
```

**Features**:
- **Clause boundaries**: Subordinate, relative, complement clauses
- **Coordination**: Handle "and", "or", "but" with `repeat` combinator
- **Sentence types**: Declarative, interrogative, imperative, exclamative
- **Error recovery**: Detect fragments and run-ons with custom error handling

### Phase 4: Semantic Analysis (COMPLETED - Week 11)

#### 4.1 Named Entity Recognition (NER) ✅

Implement entity extraction:
- Pattern-based rules for common entities (dates, numbers, emails)
- Dictionary-based lookups for known entities
- Contextual disambiguation
- Entity typing: PERSON, ORG, LOC, DATE, TIME, MONEY, PERCENT, etc.

#### 4.2 Semantic Role Labeling (SRL) ✅

**Implementation Complete:**
- Rule-based SRL using clause structure analysis
- Maps syntactic arguments to semantic roles:
  - Core roles: Agent, Patient, Theme, Recipient, Beneficiary
  - Adjunct roles: Location, Time, Manner, Instrument, Purpose, Cause
- Voice detection (active vs passive) for correct role assignment
- Handles ditransitive constructions ("give X to Y")
- Classifies prepositional phrases and adverbials by semantic function

**Module**: `Nasty.Language.English.SemanticRoleLabeler`
**API**: `SemanticRoleLabeler.label(sentence) -> {:ok, [SemanticFrame.t()]}`

#### 4.3 Coreference Resolution ✅

**Implementation Complete:**
- Mention detection:
  - Pronouns (he, she, it, they) with gender/number classification
  - Proper names (from entity recognition)
  - Definite noun phrases ("the company", "the president")
- Mention pair scoring with multiple heuristics:
  - Distance/recency (prefer mentions within 3 sentences)
  - Gender and number agreement checking
  - String matching (exact and partial)
  - Entity type consistency
  - Pronoun-name affinity boost
- Agglomerative clustering to build coreference chains
- Representative mention selection (prefer proper names)

**Module**: `Nasty.Language.English.CoreferenceResolver`
**API**: `CoreferenceResolver.resolve(document) -> {:ok, [CorefChain.t()]}`

### Phase 5: NLP Operations (Week 6-7)

#### 5.1 Text Summarization

**Extractive Summarization**
- Sentence scoring based on:
  - Position (first sentences of paragraphs)
  - Term frequency (important words)
  - Discourse markers ("in conclusion", "importantly")
  - Entity density (sentences with many named entities)
- Sentence selection algorithm (greedy, MMR)
- Summary coherence optimization

**Abstractive Summarization (Basic)**
- Sentence simplification (remove modifiers, subordinate clauses)
- Sentence fusion (combine similar sentences)
- Paraphrasing (lexical substitution)
- Discourse-aware generation

#### 5.2 Question Answering (Basic)

- Parse question to extract:
  - Question type (who, what, when, where, why, how)
  - Expected answer type
  - Key entities and relations
- Match against document AST structure
- Extract relevant spans

#### 5.3 Text Classification

- Feature extraction from AST:
  - Bag of words (lemmatized)
  - N-grams
  - Syntactic patterns
  - Entity types
- Classification algorithms (Naive Bayes, SVM)

#### 5.4 Information Extraction

- Relation extraction based on dependency paths
- Event extraction from verb phrases
- Template-based extraction for structured data

### Phase 6: AST ↔ Code Interoperability (Week 7-8)

#### 6.1 Natural Language → Code AST

Define mapping strategies:

**Imperative Statements → Function Calls**
- "Sort the list" → `List.sort(list)`
- "Calculate the sum" → `Enum.sum(values)`

**Declarative Statements → Variable Assignments**
- "X is 5" → `x = 5`
- "The result is X plus Y" → `result = x + y`

**Conditionals → If/Case Expressions**
- "If X is greater than 5, return true" → `if x > 5, do: true`

**Loops → Comprehensions/Recursion**
- "For each item in the list" → `for item <- list`

**Questions → Assertions/Tests**
- "Is X equal to 5?" → `assert x == 5`

Implement converter:
```elixir
defmodule Nasty.Interop.CodeGen.Elixir do
  @spec convert(Nasty.AST.Sentence.t()) :: {:ok, Macro.t()} | {:error, term()}
  def convert(sentence) do
    # Parse imperative/declarative intent
    # Map NL constructs to code constructs
    # Generate Elixir AST (using quote/unquote)
  end
end
```

#### 6.2 Code AST → Natural Language

Reverse mapping:
- Function calls → Imperative statements
- Assignments → Declarative statements  
- Control flow → Conditional/loop descriptions
- Module/function structure → Hierarchical descriptions

```elixir
defmodule Nasty.Interop.CodeGen.Explain do
  @spec explain(Macro.t(), language: atom()) :: Nasty.AST.Sentence.t()
  def explain(ast, opts) do
    # Traverse code AST
    # Generate natural language AST in target language
    # Render to text
  end
end
```

#### 6.3 Semantic Bridge Layer

Create intermediate representation:
- **Intent Representation**: High-level semantic intent (ACTION, QUERY, DEFINITION)
- **Entity-Relation Model**: Common structure for both NL and code
- **Type System Mapping**: NL types (person, place, thing) ↔ Code types (string, int, struct)

### Phase 7: Rendering & Utilities (Week 8-9)

#### 7.1 AST → Text Renderer

Generate natural text from AST:
- Surface realization (choose word forms)
- Agreement (subject-verb, determiner-noun)
- Word order (handle variations)
- Punctuation insertion
- Formatting (capitalization, spacing)

#### 7.2 AST Traversal & Queries

Implement utilities:
- **Visitor pattern** for tree traversal
- **Pattern matching** for node queries
- **Transformation pipelines** (AST → AST)
- **Pretty printing** for debugging

#### 7.3 Visualization

Create visual representations:
- **Parse trees**: Hierarchical phrase structure
- **Dependency graphs**: Arc diagrams
- **Entity graphs**: Coreference chains
- Export to DOT/Graphviz format

#### 7.4 Validation & Testing

- AST schema validation
- Grammar rule consistency checks
- Round-trip testing (Text → AST → Text)
- Regression test suite with linguistic phenomena

## Phase 8: Statistical Models (COMPLETED - Week 9-10)

### 8.1 Hidden Markov Model POS Tagger ✅

**Implementation Complete**:
- HMM with Viterbi decoding algorithm
- Trigram transitions with add-k smoothing
- Log-space computation to prevent underflow
- Training from Universal Dependencies CoNLL-U format
- Model persistence using Erlang Term Format (.etf)
- ~95% accuracy on UD-EWT test set vs ~85% rule-based

**Module**: `Nasty.Statistics.POSTagging.HMMTagger`

```elixir
# Train a model
training_data = [{["The", "cat", "sat"], [:det, :noun, :verb]}, ...]
model = HMMTagger.new(smoothing_k: 0.001)
{:ok, trained} = HMMTagger.train(model, training_data, [])

# Use the model
{:ok, tags} = HMMTagger.predict(trained, ["The", "dog", "runs"], [])

# Save/load
HMMTagger.save(trained, "priv/models/en/pos_hmm.model")
{:ok, loaded} = HMMTagger.load("priv/models/en/pos_hmm.model")
```

### 8.2 Model Infrastructure ✅

**Training and Evaluation**:
- `Nasty.Statistics.Model` - Common behaviour for all statistical models
- `Nasty.Statistics.Evaluator` - Metrics (accuracy, precision, recall, F1, confusion matrix)
- `Nasty.Statistics.FeatureExtractor` - Rich feature extraction utilities

**Data Layer**:
- `Nasty.Data.CoNLLU` - Parser for Universal Dependencies format
- `Nasty.Data.Corpus` - Corpus loading, splitting, and sequence extraction

**Model Management**:
- `Nasty.Statistics.ModelRegistry` - Runtime model registry (Agent-based)
- `Nasty.Statistics.ModelLoader` - Lazy loading and caching
- `Nasty.Statistics.ModelDownloader` - Fetch pretrained models from GitHub releases

**Mix Tasks**:
- `mix nasty.train.pos` - Train POS tagger from CoNLL-U corpus
- `mix nasty.eval.pos` - Evaluate model with detailed metrics
- `mix nasty.models` - List, inspect, and manage models

### 8.3 GitHub Actions Workflow ✅

**Automated Model Training**:
- `.github/workflows/train-models.yml` - Trains models on UD corpora
- Downloads Universal Dependencies data
- Trains HMM POS tagger
- Evaluates and uploads artifacts
- Publishes models as GitHub releases

### 8.4 Integration with Existing Pipeline ✅

**Enhanced POS Tagging**:
```elixir
# Rule-based (default, fast)
{:ok, tokens} = English.tag_pos(tokens)

# Statistical (higher accuracy)
{:ok, tokens} = English.tag_pos(tokens, model: :hmm)

# Ensemble (best of both)
{:ok, tokens} = English.tag_pos(tokens, model: :ensemble)
```

**Module**: `Nasty.Language.English.POSTagger` now supports:
- `:rule` - Original rule-based tagger
- `:hmm` - Statistical HMM tagger
- `:ensemble` - Weighted combination (70% HMM, 30% rules)

### 8.5 Documentation ✅

- `STATISTICAL_MODELS.md` - Complete guide to statistical models
- `TRAINING_GUIDE.md` - Step-by-step training instructions
- Example scripts in `examples/pretrained_model_usage.exs`
- Quick training script: `scripts/quick_train_model.sh`

### 8.6 Testing ✅

- `test/statistics/model_registry_test.exs`
- `test/statistics/model_loader_test.exs`
- `test/statistics/pos_tagging/hmm_tagger_test.exs`
- `test/data/conllu_test.exs`
- `test/data/corpus_test.exs`

## Project Structure

```
nasty/
├── lib/
│   ├── nasty.ex                       # Main API
│   ├── language/
│   │   ├── behaviour.ex               # Language behaviour definition
│   │   ├── parser.ex                  # Generic parser interface
│   │   ├── renderer.ex                # Generic renderer interface
│   │   ├── registry.ex                # Language registry
│   │   └── english/                   # English implementation
│   │       ├── english.ex             # English language module
│   │       ├── tokenizer.ex           # English tokenizer
│   │       ├── pos_tagger.ex          # English POS tagger
│   │       ├── morphology.ex          # English morphology
│   │       ├── grammar.ex             # English grammar rules
│   │       └── renderer.ex            # English text renderer
│   ├── ast/
│   │   ├── node.ex                    # Base node types
│   │   ├── token.ex                   # Token representation
│   │   ├── phrase.ex                  # Phrase nodes (NP, VP, PP, ...)
│   │   ├── clause.ex                  # Clause structures
│   │   ├── sentence.ex                # Sentence representation
│   │   ├── document.ex                # Document structure
│   │   ├── entity.ex                  # Semantic entities
│   │   ├── relation.ex                # Semantic relations
│   │   └── dependency.ex              # Dependency arcs
│   ├── parsing/
│   │   ├── grammar.ex                 # Grammar rules engine
│   │   ├── phrase_parser.ex           # Phrase structure parsing
│   │   ├── dependency_parser.ex       # Dependency parsing
│   │   ├── clause_parser.ex           # Clause identification
│   │   └── sentence_parser.ex         # Sentence parsing
│   ├── semantic/
│   │   ├── ner.ex                     # Named entity recognition
│   │   ├── srl.ex                     # Semantic role labeling
│   │   ├── coref.ex                   # Coreference resolution
│   │   └── disambiguation.ex          # Word sense disambiguation
│   ├── statistics/                    # ✅ Statistical models layer
│   │   ├── model.ex                   # Common model behaviour
│   │   ├── evaluator.ex               # Metrics and evaluation
│   │   ├── feature_extractor.ex       # Feature engineering
│   │   ├── model_registry.ex          # Runtime model registry
│   │   ├── model_loader.ex            # Lazy loading and caching
│   │   ├── model_downloader.ex        # Download from releases
│   │   └── pos_tagging/
│   │       └── hmm_tagger.ex          # ✅ HMM with Viterbi
│   ├── data/                          # ✅ Training data layer
│   │   ├── conllu.ex                  # Universal Dependencies parser
│   │   └── corpus.ex                  # Corpus loading and management
│   ├── mix/                           # ✅ Mix tasks
│   │   └── tasks/
│   │       └── nasty/
│   │           ├── train_pos.ex       # Train POS tagger
│   │           ├── eval_pos.ex        # Evaluate models
│   │           └── models.ex          # Model management
│   ├── operations/
│   │   ├── summarization.ex           # Text summarization
│   │   ├── question_answering.ex      # QA system
│   │   ├── classification.ex          # Text classification
│   │   └── extraction.ex              # Information extraction
│   ├── interop/
│   │   ├── code_gen/
│   │   │   ├── elixir.ex              # NL → Elixir AST
│   │   │   ├── erlang.ex              # NL → Erlang AST
│   │   │   └── explain.ex             # Code AST → NL
│   │   ├── intent.ex                  # Intent representation
│   │   └── bridge.ex                  # Semantic bridge
│   ├── rendering/
│   │   ├── text.ex                    # AST → Text
│   │   ├── pretty_print.ex            # Human-readable AST
│   │   └── visualization.ex           # DOT/Graphviz export
│   └── utils/
│       ├── traversal.ex               # AST traversal
│       ├── query.ex                   # AST queries
│       ├── transform.ex               # AST transformations
│       └── validator.ex               # AST validation
├── priv/
│   ├── models/                        # ✅ Trained model files
│   │   └── en/
│   │       └── pos_hmm_v1.model       # HMM POS tagger
│   └── languages/
│       ├── english/
│       │   ├── lexicons/
│       │   │   ├── irregular_verbs.txt        # Irregular verb forms
│       │   │   ├── irregular_nouns.txt        # Irregular noun plurals
│       │   │   └── stop_words.txt             # Common stop words
│       │   └── grammars/
│       │       ├── phrase_rules.ex            # CFG phrase rules
│       │       └── dependency_rules.ex        # Dependency templates
│       ├── spanish/                   # Future: Spanish resources
│       └── catalan/                   # Future: Catalan resources
├── test/
│   ├── language/
│   │   ├── english/
│   │   ├── behaviour_test.exs
│   │   └── registry_test.exs
│   ├── ast/
│   ├── parsing/
│   ├── semantic/
│   ├── statistics/                    # ✅ Statistical model tests
│   │   ├── model_registry_test.exs
│   │   ├── model_loader_test.exs
│   │   └── pos_tagging/
│   │       └── hmm_tagger_test.exs
│   ├── data/                          # ✅ Data layer tests
│   │   ├── conllu_test.exs
│   │   └── corpus_test.exs
│   ├── operations/
│   ├── interop/
│   └── fixtures/
│       ├── english/
│       │   ├── sentences.txt          # Test sentences
│       │   └── expected_asts.exs      # Expected parse results
│       ├── spanish/                   # Future: Spanish test data
│       └── catalan/                   # Future: Catalan test data
├── examples/
│   ├── basic_parsing.exs              # Simple parsing example
│   ├── summarization.exs              # Summarization demo
│   ├── pretrained_model_usage.exs     # ✅ Using statistical models
│   ├── code_generation.exs            # NL → Code
│   ├── code_explanation.exs           # Code → NL
│   └── question_answering.exs         # QA demo
├── scripts/                           # ✅ Utility scripts
│   └── quick_train_model.sh           # Quick model training
├── docs/
│   ├── ARCHITECTURE.md                # Language-agnostic architecture
│   ├── AST_REFERENCE.md               # Complete AST node reference
│   ├── LANGUAGE_GUIDE.md              # Adding new languages
│   ├── PARSING_GUIDE.md               # Parsing algorithm details
│   ├── INTEROP_GUIDE.md               # Code interoperability guide
│   ├── API.md                         # Public API documentation
│   ├── STATISTICAL_MODELS.md          # ✅ Statistical models guide
│   ├── TRAINING_GUIDE.md              # ✅ Model training guide
│   └── languages/
│       ├── ENGLISH_GRAMMAR.md         # English grammar specification
│       ├── SPANISH_GRAMMAR.md         # Future: Spanish grammar
│       └── CATALAN_GRAMMAR.md         # Future: Catalan grammar
├── PLAN.md                            # This file
├── README.md
└── mix.exs
```

## Key APIs

### Core Parsing

```elixir
# Parse text to AST (auto-detect language or specify)
text = "The quick brown fox jumps over the lazy dog."
{:ok, ast} = Nasty.parse(text)

# With language specified
{:ok, ast} = Nasty.parse(text, language: :en)

# With options
{:ok, ast} = Nasty.parse(text,
  language: :en,
  tokenize: true,
  pos_tag: true,
  parse_dependencies: true,
  extract_entities: true,
  resolve_coreferences: false
)
```

### AST Queries

```elixir
# Find all noun phrases
noun_phrases = Nasty.Query.find_all(ast, :noun_phrase)

# Find subject of sentence
subject = Nasty.Query.find_subject(sentence)

# Extract all entities
entities = Nasty.Query.extract_entities(ast, type: :PERSON)
```

### Summarization

```elixir
# Extractive summary
text = "...long document..."
summary = Nasty.summarize(text, language: :en, method: :extractive, sentences: 3)

# Abstractive summary (basic)
summary = Nasty.summarize(text, language: :en, method: :abstractive, max_length: 100)
```

### Code Interoperability

```elixir
# Natural language to code
nl = "Sort the list of numbers in ascending order"
{:ok, code_ast} = Nasty.to_code(nl, source_language: :en, target_language: :elixir)
code_string = Macro.to_string(code_ast)
# => "Enum.sort(numbers)"

# Code to natural language
code = quote do: Enum.map(list, fn x -> x * 2 end)
{:ok, explanation} = Nasty.explain_code(code, target_language: :en)
text = Nasty.render(explanation)
# => "Map over the list, multiplying each element by 2"
```

### Rendering

```elixir
# AST back to text (uses language from AST metadata)
text = Nasty.render(ast)

# Render to different language (future)
text = Nasty.render(ast, target_language: :es)

# Pretty print AST for debugging
Nasty.PrettyPrint.inspect(ast)

# Visualize parse tree
dot_graph = Nasty.Visualization.to_dot(ast)
```

## Dependencies

**Core**
- `nimble_parsec`: Parser combinator library for grammar rules (primary parsing approach)
- `:json` module (built-in OTP 27+): JSON serialization for AST export

**Optional**
- `graphvix`: DOT file generation for visualization

## Success Criteria

1. **AST Coverage**: Handle 50+ common English sentence patterns
2. **Parsing Accuracy**: >85% correct parse trees on test corpus
3. **Summarization Quality**: ROUGE scores comparable to baseline extractive methods
4. **Code Generation**: Successfully convert 20+ natural language commands to valid Elixir code
5. **Performance**: Parse typical sentence (<20 words) in <50ms
6. **Documentation**: Complete grammar specification and API docs
7. **Test Coverage**: >80% coverage with linguistic test suite
8. **Language Abstraction**: Clean `@behaviour` interface for adding new languages

## Future Directions

- ✅ **Machine Learning Integration**: HMM-based POS tagging with 95% accuracy (COMPLETED)
- **Multi-language Support**: Spanish, Catalan, and other natural languages
- **Advanced Statistical Models**: 
  - PCFG parser for phrase structure
  - CRF for named entity recognition
  - Neural models for improved accuracy
- **Advanced Summarization**: Attention-based abstractive models
- **Dialogue Systems**: Conversational context tracking
- **Code Understanding**: Full program comprehension and explanation
- **Formal Semantics**: Lambda calculus representation for logical inference
- **Integration with Ragex**: Use as NLP backend for code+text hybrid analysis
- **Cross-language Translation**: NL(English) ↔ NL(Spanish) via shared AST representation
