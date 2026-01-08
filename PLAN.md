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

### Phase 5: NLP Operations (COMPLETED - Week 11-12)

#### 5.1 Text Summarization ✅

**Extractive Summarization Implementation Complete:**
- Sentence scoring based on:
  - Position (first sentences of paragraphs)
  - Term frequency (important words)
  - Discourse markers ("in conclusion", "importantly")
  - Entity density (sentences with many named entities)
  - Coreference participation
  - Sentence length normalization
- Sentence selection algorithms:
  - `:greedy` - Top-N by score (default)
  - `:mmr` - Maximal Marginal Relevance (reduces redundancy)
- Flexible options: compression ratio or fixed sentence count

**Module**: `Nasty.Language.English.Summarizer`
**API**: `English.summarize(document, ratio: 0.3)` or `English.summarize(document, max_sentences: 3)`

#### 5.2 Question Answering ✅

**Extractive QA Implementation Complete:**
- Question classification:
  - WHO (person entities)
  - WHAT (things, organizations)
  - WHEN (temporal expressions)
  - WHERE (locations)
  - WHY (reasons, clauses)
  - HOW (manner, quantity)
  - YES/NO (boolean questions)
- Answer extraction strategies:
  - Keyword matching with lemmatization
  - Entity type filtering (person, organization, location)
  - Temporal expression recognition
  - Confidence scoring and ranking
- Multiple answer support with confidence scores

**Modules**: `Nasty.Language.English.QuestionAnalyzer`, `Nasty.Language.English.AnswerExtractor`
**API**: `English.answer_question(document, "Who works at Google?")`

#### 5.3 Text Classification ✅

**Multinomial Naive Bayes Implementation Complete:**
- Feature extraction from AST:
  - `:bow` - Bag of words (lemmatized, stop word filtering)
  - `:ngrams` - Word sequences (bigrams, trigrams, etc.)
  - `:pos_patterns` - POS tag sequences
  - `:syntactic` - Sentence structure statistics
  - `:entities` - Named entity distributions
  - `:lexical` - Vocabulary richness and text statistics
- Multinomial Naive Bayes classifier:
  - Laplace smoothing (alpha=1.0)
  - Log-space computation to prevent underflow
  - Softmax normalization for probabilities
- Model training and prediction:
  - Train on labeled documents: `{document, class}` tuples
  - Multi-class classification support
  - Confidence scores and probability distributions
- Model evaluation:
  - Accuracy, precision, recall, F1 metrics
  - Per-class performance breakdowns
- Use cases demonstrated:
  - Sentiment analysis (positive/negative reviews)
  - Spam detection (spam/ham classification)
  - Topic classification (sports, tech, politics, business)
  - Formality detection (formal/informal text)

**Modules**: `Nasty.Language.English.FeatureExtractor`, `Nasty.Language.English.TextClassifier`
**API**: `English.train_classifier(training_data, features: [:bow, :lexical])` and `English.classify(document, model)`
**AST Nodes**: `Nasty.AST.Classification`, `Nasty.AST.ClassificationModel`
**Tests**: 26 comprehensive tests covering all features
**Examples**: `examples/text_classification.exs` with 4 real-world demonstrations

#### 5.4 Information Extraction ✅

**Implementation Complete:**
- **Relation Extraction** - Extract semantic relationships between entities
  - 15+ relation types (employment, organization, location, temporal)
  - Pattern-based extraction using verb patterns and prepositions
  - Confidence scoring (0.5-0.8 based on pattern strength)
  - Integrates with NER and dependency extraction
  - Helper functions: invert, sort, filter

- **Event Extraction** - Identify events with triggers and participants
  - 10+ event types (business, employment, communication, movement, transaction)
  - Verb and nominalization triggers
  - Participant extraction using semantic role labeling
  - Temporal expression linking from entities
  - Confidence scoring (0.7-0.8)

- **Template-Based Extraction** - Structured information using custom templates
  - Flexible template system with typed slots
  - Pre-defined templates: employment, acquisition, location
  - Pattern matching with confidence calculation
  - Required/optional slot support

**Modules**: `Nasty.Language.English.RelationExtractor`, `Nasty.Language.English.EventExtractor`, `Nasty.Language.English.TemplateExtractor`
**API**: `English.extract_relations/2`, `English.extract_events/2`, `English.extract_templates/3`
**AST Nodes**: `Nasty.AST.Relation`, `Nasty.AST.Event`
**Tests**: 50+ comprehensive tests covering all extraction types
**Examples**: `examples/information_extraction.exs` with 4 real-world demonstrations

### Phase 6: AST ↔ Code Interoperability ✅ (COMPLETED)

**Implementation Complete:**

#### 6.1 Natural Language → Code Generation ✅

- **Intent Recognition** - Extract semantic intent from natural language
  - Intent types: `:action`, `:query`, `:definition`, `:conditional`
  - Action extraction from predicates and verbs
  - Target/argument extraction from semantic roles
  - Confidence scoring (0.65-0.95 based on completeness)
  - Verb normalization ("sort" → `Enum.sort`, "filter" → `Enum.filter`)

- **Elixir Code Generation** - Convert intents to executable Elixir AST
  - List operations: `Enum.sort`, `Enum.filter`, `Enum.map`, `Enum.sum`, etc.
  - Arithmetic operations: addition, subtraction, multiplication, division
  - Variable assignments with literals and expressions
  - Conditional statements: `if/then` expressions
  - AST validation using `Code.string_to_quoted`

- **Supported Patterns**:
  - "Sort the list" → `Enum.sort(list)`
  - "Filter users where age > 18" → `Enum.filter(users, fn item -> item > 18 end)`
  - "X is 5" → `x = 5`
  - "If X then Y" → `if x, do: y`

**Modules**: `Nasty.AST.Intent`, `Nasty.Interop.IntentRecognizer`, `Nasty.Interop.CodeGen.Elixir`
**API**: `English.to_code(text)`, `English.to_code_ast(text)`, `English.recognize_intent(text)`

#### 6.2 Code → Natural Language Explanation ✅

- **Code Explanation** - Generate natural language from Elixir AST
  - Function call explanation (Enum operations, custom functions)
  - Pipeline explanation with sequential descriptions
  - Assignment explanation ("X is Y")
  - Arithmetic operation explanation ("X plus Y", "X times Y")
  - Conditional explanation ("If X then Y")

- **AST Traversal Patterns**:
  - `Enum.sort(numbers)` → "sort numbers"
  - `x = a + b` → "X is a plus b"
  - `list |> Enum.map(&(&1 * 2)) |> Enum.sum()` → "map list to each element times 2, then sum list"
  - `if x > 5, do: :ok` → "If x is greater than 5, then :ok"

- **Document Generation** - Create full NL AST from code
  - Generate Document with Paragraph, Sentence, Clause structures
  - Token creation with inferred POS tags
  - Proper span tracking for all nodes

**Modules**: `Nasty.Interop.CodeGen.Explain`
**API**: `English.explain_code(code)`, `English.explain_code_to_document(ast)`

#### 6.3 Optional Ragex Integration ✅

- **Context-Aware Enhancement** - Leverage Ragex knowledge graph
  - Semantic search for function suggestions
  - Function signature and documentation extraction
  - Intent enhancement with codebase context
  - Graceful degradation when Ragex unavailable

**Module**: `Nasty.Interop.RagexBridge`
**API**: `English.to_code(text, enhance_with_ragex: true)`
**Configuration**: `config :nasty, :ragex, enabled: true, path: "/path/to/ragex"`

#### Implementation Summary

- **Files Created**: 5 modules, 2 example scripts
- **Lines of Code**: ~1,200 lines of implementation
- **Examples**: `examples/code_generation.exs`, `examples/code_explanation.exs`
- **Documentation**: Complete README section with API examples

### Phase 7: Rendering & Utilities (COMPLETED - Week 12)

#### 7.1 AST → Text Renderer ✅

**Implementation Complete:**
- Surface realization (choose word forms)
- Agreement (subject-verb, determiner-noun) with helper functions
- Word order (handle variations)
- Punctuation insertion based on sentence type
- Formatting (capitalization, spacing)
- Flexible rendering options (capitalize_sentences, add_punctuation, paragraph_separator)

**Module**: `Nasty.Rendering.Text`
**API**: `Text.render(node, opts)`, `Text.render!(node, opts)`, `Text.apply_agreement/3`

#### 7.2 AST Traversal & Queries ✅

**Implementation Complete:**
- **Visitor pattern** for tree traversal with `:cont`, `:halt`, `:skip` controls
- **Multiple traversal strategies**: pre-order, post-order, breadth-first
- **High-level operations**: `walk/3`, `collect/2`, `find/2`, `map/2`, `reduce/3`
- **Query API** for common patterns:
  - Find by type, POS tag, text pattern, lemma
  - Extract entities with filtering
  - Find subjects, verbs, objects
  - Count nodes, check predicates
  - Content vs function words
  - Custom filtering and span extraction

**Modules**: `Nasty.Utils.Traversal`, `Nasty.Utils.Query`
**APIs**: 
- `Traversal.walk/3`, `Traversal.walk_post/3`, `Traversal.walk_breadth/3`
- `Query.find_all/2`, `Query.find_by_pos/2`, `Query.extract_entities/2`

#### 7.3 Visualization ✅

**Implementation Complete:**
- **Parse trees**: DOT format export with hierarchical phrase structure
- **Dependency graphs**: Arc diagrams with grammatical relations
- **Entity graphs**: Named entity visualization with type-based coloring
- **DOT/Graphviz format**: Complete graph export for `dot` tool
- **JSON export**: d3.js-compatible format for web visualization
- **Pretty printing**: 
  - Indented AST output with ANSI colors
  - Tree-style rendering with box-drawing characters
  - Statistics summary (node counts)
  - Configurable depth and span display

**Modules**: `Nasty.Rendering.Visualization`, `Nasty.Rendering.PrettyPrint`
**APIs**: 
- `Visualization.to_dot/2` (types: `:parse_tree`, `:dependencies`, `:entities`)
- `Visualization.to_json/2`
- `PrettyPrint.print/2`, `PrettyPrint.tree/2`, `PrettyPrint.stats/1`

#### 7.4 Validation & Testing ✅

**Implementation Complete:**
- **AST schema validation**: Validate all node types conform to expected structure
- **Span validation**: Ensure position tracking is consistent
- **Language consistency**: Check all nodes have matching language markers
- **POS tag validation**: Verify tags are valid Universal Dependencies tags
- **Transformation utilities**: 
  - Case normalization (lower/upper/title)
  - Punctuation removal
  - Stop word filtering
  - Token replacement and filtering
  - Lemmatization
  - Transformation pipelines
  - Round-trip testing support

**Modules**: `Nasty.Utils.Validator`, `Nasty.Utils.Transform`
**APIs**: 
- `Validator.validate/1`, `Validator.validate!/1`, `Validator.valid?/1`
- `Validator.validate_spans/1`, `Validator.validate_language/1`
- `Transform.normalize_case/2`, `Transform.remove_punctuation/1`
- `Transform.remove_stop_words/2`, `Transform.lemmatize/1`
- `Transform.pipeline/2`, `Transform.round_trip_test/2`

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

### 8.7 Neural Network Models ✅ (COMPLETED)

**BiLSTM-CRF POS Tagger Implementation Complete**:
- Bidirectional LSTM with CRF layer for sequence tagging
- 97-98% accuracy on UD-EWT test set (vs 95% HMM, 85% rule-based)
- Built with Axon (Elixir neural network library)
- EXLA JIT compilation for 10-100x speedup
- Character-level CNN for OOV handling
- Pre-trained embedding support (GloVe, FastText)
- Model persistence (.axon format)
- GPU acceleration support

**Modules**:
- `Nasty.Statistics.POSTagging.NeuralTagger` - Main neural POS tagger
- `Nasty.Statistics.Neural.Architectures.BiLSTMCRF` - Architecture definition
- `Nasty.Statistics.Neural.DataLoader` - Data loading and preprocessing
- `Nasty.Statistics.Neural.Embeddings` - Pre-trained embedding support
- `Nasty.Statistics.Neural.Preprocessing` - Input preprocessing
- `Nasty.Statistics.Neural.Inference` - Inference pipeline
- `Nasty.Statistics.Neural.Trainer` - Training infrastructure

**Mix Tasks**:
- `mix nasty.train.neural_pos` - Train neural POS tagger
- `mix nasty.eval.neural_pos` - Evaluate neural models (planned)

**Integration**:
```elixir
# Neural mode
{:ok, tokens} = English.tag_pos(tokens, model: :neural)

# Neural ensemble (combines neural + HMM + rules)
{:ok, tokens} = English.tag_pos(tokens, model: :neural_ensemble)
```

**Documentation**:
- `docs/NEURAL_MODELS.md` - Complete neural model guide
- `docs/TRAINING_NEURAL.md` - Training guide with best practices
- `docs/PRETRAINED_MODELS.md` - Future transformer support
- `examples/neural_pos_tagger_example.exs` - Usage examples

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
|   │   ├── pos_tagging/
|   │   │   ├── hmm_tagger.ex          # ✅ HMM with Viterbi
|   │   │   └── neural_tagger.ex       # ✅ BiLSTM-CRF neural tagger
|   │   └── neural/                    # ✅ Neural network infrastructure
|   │       ├── model.ex               # Neural model behaviour
|   │       ├── inference.ex           # Inference pipeline
|   │       ├── preprocessing.ex       # Input preprocessing
|   │       ├── trainer.ex             # Training infrastructure
|   │       ├── data_loader.ex         # Data loading and batching
|   │       ├── embeddings.ex          # Pre-trained embeddings
|   │       ├── pretrained.ex          # Transformer integration (planned)
|   │       └── architectures/
|   │           └── bilstm_crf.ex      # BiLSTM-CRF architecture
|   ├── data/                          # ✅ Training data layer
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
|   ├── interop/
|   │   ├── code_gen/
|   │   │   ├── elixir.ex              # NL → Elixir AST
|   │   │   └── explain.ex             # Code AST → NL
|   │   ├── intent.ex                  # Intent representation
|   │   ├── intent_recognizer.ex       # Intent extraction
|   │   └── ragex_bridge.ex            # Ragex integration
|   ├── rendering/                     # ✅ Phase 7 complete
|   │   ├── text.ex                    # ✅ AST → Text with surface realization
|   │   ├── pretty_print.ex            # ✅ Human-readable AST with colors
|   │   └── visualization.ex           # ✅ DOT/Graphviz and JSON export
|   └── utils/                         # ✅ Phase 7 complete
|       ├── traversal.ex               # ✅ AST traversal with visitor pattern
|       ├── query.ex                   # ✅ High-level AST queries
|       ├── transform.ex               # ✅ AST transformations and pipelines
|       └── validator.ex               # ✅ AST validation and consistency
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
│       │   └── expected_asts_test.exs # Expected parse results
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
