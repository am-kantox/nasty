# Nasty AST Reference

Complete reference for all Abstract Syntax Tree (AST) node types in Nasty.

## Overview

The Nasty AST is a hierarchical structure representing natural language with linguistic precision. All nodes include:

- `language` - Language code (`:en`, `:es`, `:ca`, etc.)
- `span` - Position tracking with line/column and byte offsets

## Document Structure

### Document

Top-level node representing an entire text unit.

**Module:** `Nasty.AST.Document`

**Fields:**
- `paragraphs` - List of Paragraph nodes
- `language` - Document language
- `metadata` - Map with optional fields:
  - `title` - Document title
  - `author` - Author name(s)
  - `date` - Creation/modification date
  - `source` - Original source
- `semantic_frames` - Optional semantic frames
- `coref_chains` - Optional coreference chains
- `span` - Document position

**Example:**
```elixir
%Nasty.AST.Document{
  paragraphs: [paragraph1, paragraph2],
  language: :en,
  metadata: %{title: "My Essay", author: "Jane Doe"},
  span: span
}
```

**Functions:**
- `Document.new/4` - Create document
- `Document.all_sentences/1` - Flatten all sentences
- `Document.paragraph_count/1` - Count paragraphs
- `Document.sentence_count/1` - Count sentences

### Paragraph

Sequence of related sentences dealing with a single topic.

**Module:** `Nasty.AST.Paragraph`

**Fields:**
- `sentences` - List of Sentence nodes
- `topic_sentence` - Optional topic sentence
- `language` - Paragraph language
- `span` - Paragraph position

**Example:**
```elixir
%Nasty.AST.Paragraph{
  sentences: [sentence1, sentence2, sentence3],
  language: :en,
  span: span
}
```

**Functions:**
- `Paragraph.new/4` - Create paragraph
- `Paragraph.first_sentence/1` - Get first sentence
- `Paragraph.last_sentence/1` - Get last sentence
- `Paragraph.sentence_count/1` - Count sentences

## Sentence Structure

### Sentence

Complete grammatical unit consisting of one or more clauses.

**Module:** `Nasty.AST.Sentence`

**Fields:**
- `function` - Sentence function:
  - `:declarative` - Statement ("The cat sat.")
  - `:interrogative` - Question ("Did the cat sit?")
  - `:imperative` - Command ("Sit!")
  - `:exclamative` - Exclamation ("What a cat!")
- `structure` - Sentence structure:
  - `:simple` - One independent clause
  - `:compound` - Multiple independent clauses
  - `:complex` - Independent + dependent clause(s)
  - `:compound_complex` - Multiple independent + dependent
  - `:fragment` - Incomplete sentence
- `main_clause` - Primary Clause node
- `additional_clauses` - List of additional Clause nodes
- `language` - Sentence language
- `span` - Sentence position

**Example:**
```elixir
%Nasty.AST.Sentence{
  function: :declarative,
  structure: :simple,
  main_clause: clause,
  additional_clauses: [],
  language: :en,
  span: span
}
```

**Functions:**
- `Sentence.new/6` - Create sentence
- `Sentence.infer_structure/2` - Infer structure from clauses
- `Sentence.all_clauses/1` - Get all clauses
- `Sentence.question?/1` - Check if question
- `Sentence.command?/1` - Check if command
- `Sentence.complete?/1` - Check if complete

### Clause

Fundamental grammatical unit with subject and predicate.

**Module:** `Nasty.AST.Clause`

**Fields:**
- `type` - Clause type:
  - `:independent` - Can stand alone
  - `:subordinate` - Dependent on main clause
  - `:relative` - Modifies a noun
  - `:coordinate` - Joined by conjunction
- `subject` - NounPhrase (optional)
- `predicate` - VerbPhrase
- `semantic_frames` - Optional semantic role information
- `language` - Clause language
- `span` - Clause position

**Example:**
```elixir
%Nasty.AST.Clause{
  type: :independent,
  subject: noun_phrase,
  predicate: verb_phrase,
  language: :en,
  span: span
}
```

**Functions:**
- `Clause.independent?/1` - Check if independent
- `Clause.dependent?/1` - Check if dependent

## Phrase Nodes

### NounPhrase

Phrase headed by a noun.

**Module:** `Nasty.AST.NounPhrase`

**Structure:** (Determiner) (Modifiers)* Head (PostModifiers)*

**Fields:**
- `determiner` - Optional determiner token (the, a, this)
- `modifiers` - List of pre-modifying adjectives/phrases
- `head` - Main noun Token
- `post_modifiers` - List of post-modifying PP/clauses
- `entity` - Optional named entity information
- `language` - NP language
- `span` - NP position

**Examples:**
- "the cat" - determiner + head
- "the quick brown fox" - determiner + modifiers + head
- "the cat on the mat" - determiner + head + PP modifier

```elixir
%Nasty.AST.NounPhrase{
  determiner: %Token{text: "the", ...},
  modifiers: [%Token{text: "quick", pos_tag: :adj, ...}],
  head: %Token{text: "fox", pos_tag: :noun, ...},
  post_modifiers: [],
  language: :en,
  span: span
}
```

### VerbPhrase

Phrase headed by a verb.

**Module:** `Nasty.AST.VerbPhrase`

**Structure:** (Auxiliaries)* MainVerb (Complements)* (Adverbials)*

**Fields:**
- `auxiliaries` - List of auxiliary verb Tokens (is, has, will)
- `head` - Main verb Token
- `complements` - List of objects/complements
- `adverbials` - List of adverbial modifiers
- `language` - VP language
- `span` - VP position

**Examples:**
- "ran" - main verb only
- "is running" - auxiliary + main verb
- "gave the dog a bone" - verb + indirect/direct objects

```elixir
%Nasty.AST.VerbPhrase{
  auxiliaries: [%Token{text: "has", pos_tag: :aux, ...}],
  head: %Token{text: "run", pos_tag: :verb, ...},
  complements: [noun_phrase],
  adverbials: [adverb_phrase],
  language: :en,
  span: span
}
```

### PrepositionalPhrase

Phrase headed by a preposition.

**Module:** `Nasty.AST.PrepositionalPhrase`

**Structure:** Preposition + NounPhrase

**Fields:**
- `head` - Preposition Token
- `object` - NounPhrase object
- `language` - PP language
- `span` - PP position

**Examples:**
- "on the mat"
- "in the house"

```elixir
%Nasty.AST.PrepositionalPhrase{
  head: %Token{text: "on", pos_tag: :adp, ...},
  object: noun_phrase,
  language: :en,
  span: span
}
```

### AdjectivalPhrase

Phrase headed by an adjective.

**Module:** `Nasty.AST.AdjectivalPhrase`

**Structure:** (Intensifier) Adjective (Complement)

**Fields:**
- `intensifier` - Optional intensifier (very, quite)
- `head` - Adjective Token
- `complement` - Optional PP complement
- `language` - AP language
- `span` - AP position

**Examples:**
- "happy"
- "very happy"
- "happy with the result"

### AdverbialPhrase

Phrase headed by an adverb.

**Module:** `Nasty.AST.AdverbialPhrase`

**Structure:** (Intensifier) Adverb

**Fields:**
- `intensifier` - Optional intensifier
- `head` - Adverb Token
- `language` - AdvP language
- `span` - AdvP position

**Examples:**
- "quickly"
- "very quickly"

## Token

Atomic unit representing a single word or punctuation mark.

**Module:** `Nasty.AST.Token`

**Fields:**
- `text` - Surface form
- `lemma` - Base/dictionary form
- `pos_tag` - Universal Dependencies POS tag:
  - **Open class:** `:adj`, `:adv`, `:intj`, `:noun`, `:propn`, `:verb`
  - **Closed class:** `:adp`, `:aux`, `:cconj`, `:det`, `:num`, `:part`, `:pron`, `:sconj`
  - **Other:** `:punct`, `:sym`, `:x`
- `morphology` - Map of morphological features:
  - `number`: `:singular` | `:plural`
  - `tense`: `:past` | `:present` | `:future`
  - `person`: `:first` | `:second` | `:third`
  - `case`: `:nominative` | `:accusative` | `:genitive`
  - `gender`: `:masculine` | `:feminine` | `:neuter`
  - `mood`: `:indicative` | `:subjunctive` | `:imperative`
  - `voice`: `:active` | `:passive`
- `language` - Token language
- `span` - Token position

**Example:**
```elixir
%Nasty.AST.Token{
  text: "cats",
  lemma: "cat",
  pos_tag: :noun,
  morphology: %{number: :plural},
  language: :en,
  span: span
}
```

**Functions:**
- `Token.new/5` - Create token
- `Token.pos_tags/0` - List all POS tags
- `Token.content_word?/1` - Check if content word
- `Token.function_word?/1` - Check if function word

## Semantic Nodes

### Entity

Named entity with type classification.

**Module:** `Nasty.AST.Semantic.Entity`

**Fields:**
- `text` - Entity surface text
- `type` - Entity type:
  - `:person` - Person names
  - `:organization` - Companies, institutions
  - `:location` - Places, addresses
  - `:date` - Dates, times
  - `:money` - Monetary values
  - `:percent` - Percentages
  - `:misc` - Other
- `tokens` - List of constituent Tokens
- `confidence` - Recognition confidence (0.0-1.0)
- `metadata` - Additional information
- `language` - Entity language
- `span` - Entity position

**Example:**
```elixir
%Nasty.AST.Semantic.Entity{
  text: "John Smith",
  type: :person,
  tokens: [token1, token2],
  confidence: 0.95,
  language: :en,
  span: span
}
```

### CorefChain

Coreference chain linking mentions of the same entity.

**Module:** `Nasty.AST.Semantic.CorefChain`

**Fields:**
- `id` - Unique chain ID
- `mentions` - List of Mention structs:
  - `tokens` - Tokens in mention
  - `head_token` - Head token
  - `span` - Mention position
  - `is_representative` - Whether canonical mention
- `entity_type` - Optional entity type

**Example:**
```elixir
%Nasty.AST.Semantic.CorefChain{
  id: 1,
  mentions: [
    %Nasty.AST.Semantic.Mention{tokens: [...], is_representative: true, ...},
    %Nasty.AST.Semantic.Mention{tokens: [...], is_representative: false, ...}
  ],
  entity_type: :person
}
```

### Frame

Semantic role frame for predicate-argument structure.

**Module:** `Nasty.AST.Semantic.Frame`

**Fields:**
- `predicate` - Frame predicate
- `frame_type` - Frame classification
- `roles` - Map of semantic roles:
  - `:agent` - Doer of action
  - `:patient` - Affected entity
  - `:theme` - Primary argument
  - `:goal` - Destination
  - `:source` - Origin
  - `:instrument` - Tool used
  - `:location` - Place
  - `:time` - Temporal info

**Example:**
```elixir
%Nasty.AST.Semantic.Frame{
  predicate: "give",
  frame_type: :transfer,
  roles: %{
    agent: noun_phrase1,
    patient: noun_phrase2,
    theme: noun_phrase3
  }
}
```

## Dependency Relations

### Dependency

Grammatical dependency relationship between tokens.

**Module:** `Nasty.AST.Dependency`

**Fields:**
- `relation` - Universal Dependencies relation type:
  - `:nsubj` - Nominal subject
  - `:obj` - Direct object
  - `:iobj` - Indirect object
  - `:obl` - Oblique nominal
  - `:amod` - Adjectival modifier
  - `:advmod` - Adverbial modifier
  - `:det` - Determiner
  - `:case` - Case marker (preposition)
  - `:cc` - Coordinating conjunction
  - `:conj` - Conjunct
  - Many more (see Universal Dependencies docs)
- `head` - Head token index
- `dependent` - Dependent token index
- `metadata` - Additional information

**Example:**
```elixir
%Nasty.AST.Dependency{
  relation: :nsubj,
  head: 2,  # verb index
  dependent: 1,  # noun index
  metadata: %{}
}
```

## Code Interoperability

### Intent

Abstract representation of code intent from natural language.

**Module:** `Nasty.AST.Intent`

**Fields:**
- `type` - Intent type:
  - `:action` - Perform action
  - `:query` - Ask question
  - `:definition` - Define/assign
  - `:conditional` - Conditional logic
- `action` - Action verb (sort, filter, etc.)
- `target` - Target variable/object
- `arguments` - List of arguments
- `constraints` - List of constraints (for filters)
- `metadata` - Additional info

**Example:**
```elixir
%Nasty.AST.Intent{
  type: :action,
  action: "filter",
  target: "users",
  arguments: [],
  constraints: [
    {:comparison, :greater_than, 18}
  ]
}
```

### Answer

Extracted answer from question answering.

**Module:** `Nasty.AST.Answer`

**Fields:**
- `text` - Answer text
- `tokens` - Answer tokens
- `sentence` - Source sentence
- `confidence` - Confidence score
- `method` - Extraction method
- `metadata` - Additional info

**Example:**
```elixir
%Nasty.AST.Answer{
  text: "Paris",
  tokens: [token],
  sentence: sentence,
  confidence: 0.92,
  method: :entity_match
}
```

## Classification & Extraction

### Classification

Text classification result.

**Module:** `Nasty.AST.Classification`

**Fields:**
- `category` - Predicted category
- `confidence` - Confidence score
- `probabilities` - Map of category probabilities
- `features` - Features used

**Example:**
```elixir
%Nasty.AST.Classification{
  category: :positive,
  confidence: 0.87,
  probabilities: %{
    positive: 0.87,
    negative: 0.10,
    neutral: 0.03
  }
}
```

### Relation

Extracted relation between entities.

**Module:** `Nasty.AST.Relation`

**Fields:**
- `type` - Relation type
- `subject` - Subject entity
- `object` - Object entity
- `confidence` - Extraction confidence
- `context` - Source sentence/clause

**Example:**
```elixir
%Nasty.AST.Relation{
  type: :lives_in,
  subject: %Entity{text: "John", type: :person, ...},
  object: %Entity{text: "Paris", type: :location, ...},
  confidence: 0.89
}
```

### Event

Extracted event with participants.

**Module:** `Nasty.AST.Event`

**Fields:**
- `type` - Event type
- `trigger` - Trigger word/phrase
- `participants` - Map of participant roles
- `time` - Temporal info
- `location` - Location info
- `confidence` - Extraction confidence

**Example:**
```elixir
%Nasty.AST.Event{
  type: :acquisition,
  trigger: "acquired",
  participants: %{
    acquirer: entity1,
    acquired: entity2
  },
  time: date_entity,
  confidence: 0.91
}
```

## Position Tracking

### Span

Position information for precise source location tracking.

**Type:** `Nasty.AST.Node.span()`

**Structure:**
```elixir
%{
  start_pos: {line, column},
  start_byte: byte_offset,
  end_pos: {line, column},
  end_byte: byte_offset
}
```

**Functions:**
- `Node.make_span/4` - Create span
- `Node.span_length/1` - Calculate length
- `Node.spans_overlap?/2` - Check overlap

## See Also

- [API Documentation](API.md) - Public API reference
- [User Guide](USER_GUIDE.md) - Tutorial and examples
- [Universal Dependencies](https://universaldependencies.org/) - POS tags and dependency relations
