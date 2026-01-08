# Information Extraction

This document describes Nasty's information extraction capabilities, which identify and extract structured information from unstructured text.

## Overview

Nasty provides four main information extraction features:

1. **Named Entity Recognition (NER)** - Identifies entities like people, organizations, locations, dates
2. **Relation Extraction** - Discovers semantic relationships between entities
3. **Event Extraction** - Identifies events with participants, time, and location
4. **Coreference Resolution** - Resolves pronouns to their antecedents

## Named Entity Recognition (NER)

NER identifies and classifies entities mentioned in text into predefined categories.

### Supported Entity Types

- **PERSON** - Individual person names ("John Smith", "Mary")
- **ORG** - Organizations ("Google Inc.", "Harvard University")
- **LOC** - Physical locations ("Mount Everest", "Pacific Ocean")
- **GPE** - Geopolitical entities ("France", "California", "New York")
- **DATE** - Temporal expressions ("January 5", "2026", "March")
- **TIME** - Time expressions ("3:00 PM", "noon", "midnight")
- **MONEY** - Monetary values ("$100", "50 euros")
- **PERCENT** - Percentages ("25%")
- **QUANTITY** - Measurements ("5 kg", "10 meters")
- **EVENT** - Named events ("World War II", "Olympics")
- **PRODUCT** - Products/services ("iPhone", "Windows")
- **LANGUAGE** - Language names ("English", "Spanish")

### Usage

```elixir
alias Nasty.Language.English.{Tokenizer, POSTagger, EntityRecognizer}

# Parse and tag text
{:ok, tokens} = Tokenizer.tokenize("John works at Google in California.")
{:ok, tagged} = POSTagger.tag_pos(tokens)

# Recognize entities
entities = EntityRecognizer.recognize(tagged)

# Inspect results
Enum.each(entities, fn entity ->
  IO.puts("#{entity.type}: #{entity.text}")
end)

# Output:
# person: John
# org: Google
# gpe: California
```

### NER Models

Nasty supports multiple NER approaches:

```elixir
# Rule-based (default) - Fast, ~85% accuracy
entities = EntityRecognizer.recognize(tokens)

# Statistical CRF - ~90-95% accuracy
entities = EntityRecognizer.recognize(tokens, model: :crf)
```

### Entity Structure

```elixir
%Entity{
  type: :person,              # Entity type
  text: "John Smith",         # Surface text
  tokens: [token1, token2],   # Token list
  canonical_form: nil,        # Normalized form
  confidence: 0.85,           # Confidence score
  span: %{...}                # Position info
}
```

## Relation Extraction

Relation extraction identifies semantic relationships between entities in text.

### Supported Relation Types

- **Employment**: `:works_at`, `:employed_by`, `:member_of`
- **Organization**: `:founded`, `:acquired_by`, `:subsidiary_of`
- **Location**: `:located_in`, `:based_in`, `:headquarters_in`
- **Personal**: `:born_in`, `:educated_at`, `:ceo_of`
- **Structure**: `:part_of`
- **Temporal**: `:occurred_on`, `:founded_in`

### Usage

```elixir
alias Nasty.{Nasty, Language.English.RelationExtractor}

# Parse document
{:ok, document} = Nasty.parse("John works at Google in California.")

# Extract relations
{:ok, relations} = RelationExtractor.extract(document)

# Inspect results
Enum.each(relations, fn rel ->
  IO.puts("#{rel.subject.text} -[#{rel.type}]-> #{rel.object.text}")
  IO.puts("  Confidence: #{rel.confidence}")
end)

# Output:
# John -[works_at]-> Google
#   Confidence: 0.8
# Google -[located_in]-> California
#   Confidence: 0.7
```

### Options

```elixir
# Filter by confidence threshold
{:ok, relations} = RelationExtractor.extract(document, min_confidence: 0.7)

# Limit number of results
{:ok, relations} = RelationExtractor.extract(document, max_relations: 10)

# Filter by relation type (post-processing)
employment = Enum.filter(relations, fn r -> r.type == :works_at end)
```

### Relation Structure

```elixir
%Relation{
  type: :works_at,              # Relation type
  subject: %Entity{...},        # Source entity
  object: %Entity{...},         # Target entity
  confidence: 0.8,              # Confidence score
  evidence: "John works...",    # Supporting text
  span: %{...},                 # Position info
  language: :en                 # Language code
}
```

### Pattern Matching

Relations are detected using:

1. **Verb patterns**: "works at", "founded", "acquired"
2. **Preposition patterns**: "X at Y", "X in Y", "X of Y"
3. **Dependency paths**: Subject-verb-object relationships
4. **Entity type constraints**: PERSON + ORG → works_at

## Event Extraction

Event extraction identifies actions, states, or processes with their participants and circumstances.

### Supported Event Types

#### Business Events
- `:business_acquisition` - Mergers and acquisitions
- `:business_merger` - Company mergers
- `:product_launch` - Product releases
- `:company_founding` - Company establishments

#### Employment Events
- `:employment_start` - Hiring, joining
- `:employment_end` - Resignation, firing

#### Communication Events
- `:announcement` - Public announcements
- `:meeting` - Meetings, discussions

#### Movement Events
- `:movement` - Travel, arrival, departure

#### Transaction Events
- `:transaction` - Sales, trades, exchanges

### Usage

```elixir
alias Nasty.{Nasty, Language.English.EventExtractor}

# Parse document
{:ok, document} = Nasty.parse("Google acquired YouTube in October 2006.")

# Extract events
{:ok, events} = EventExtractor.extract(document)

# Inspect results
Enum.each(events, fn event ->
  IO.puts("Event: #{event.type}")
  IO.puts("  Trigger: #{event.trigger.text}")
  IO.puts("  Participants: #{inspect(event.participants)}")
  IO.puts("  Time: #{event.time}")
end)

# Output:
# Event: business_acquisition
#   Trigger: acquired
#   Participants: %{agent: google_entity, patient: youtube_entity}
#   Time: October 2006
```

### Options

```elixir
# Filter by confidence
{:ok, events} = EventExtractor.extract(document, min_confidence: 0.7)

# Limit results
{:ok, events} = EventExtractor.extract(document, max_events: 5)

# Filter by event type (post-processing)
acquisitions = Enum.filter(events, fn e -> e.type == :business_acquisition end)
```

### Event Structure

```elixir
%Event{
  type: :business_acquisition,  # Event type
  trigger: %Token{...},          # Trigger word (verb/noun)
  participants: %{               # Event participants
    agent: %Entity{...},         # Who performed action
    patient: %Entity{...},       # Who/what was affected
    location: "California"       # Where it occurred
  },
  time: "October 2006",          # When it occurred
  confidence: 0.8,               # Confidence score
  span: %{...},                  # Position info
  language: :en                  # Language code
}
```

### Event Detection

Events are detected through:

1. **Verb triggers**: "acquired", "launched", "announced"
2. **Nominalizations**: "acquisition", "merger", "announcement"
3. **Semantic roles**: Agent, patient, beneficiary extraction
4. **Temporal expressions**: DATE/TIME entity recognition

## Coreference Resolution

Coreference resolution identifies when different expressions refer to the same entity, building chains of mentions across sentences.

### Usage

```elixir
alias Nasty.{Nasty, Language.English.CoreferenceResolver}

# Parse document with multiple sentences
text = \"\"\"
John works at Google. He is an engineer.
The company is based in California.
\"\"\"

{:ok, document} = Nasty.parse(text)

# Resolve coreferences
{:ok, chains} = CoreferenceResolver.resolve(document)

# Inspect results
Enum.each(chains, fn chain ->
  IO.puts("Entity chain:")
  Enum.each(chain.mentions, fn mention ->
    IO.puts("  - #{mention.text} (#{mention.type})")
  end)
end)

# Output:
# Entity chain:
#   - John (proper_name)
#   - He (pronoun)
# Entity chain:
#   - Google (proper_name)
#   - The company (definite_np)
```

### Mention Types

- `:proper_name` - Proper nouns ("John", "Google")
- `:pronoun` - Pronouns ("he", "she", "it", "they")
- `:definite_np` - Definite noun phrases ("the company", "the president")
- `:demonstrative` - Demonstrative references ("this", "that")

### Coreference Chain Structure

```elixir
%CorefChain{
  id: "chain_1",                # Unique chain ID
  representative: %Mention{...}, # Most informative mention
  mentions: [                    # All mentions in chain
    %Mention{text: "John", type: :proper_name, ...},
    %Mention{text: "He", type: :pronoun, ...}
  ],
  entity_type: :person          # Entity type for chain
}
```

### Mention Structure

```elixir
%Mention{
  text: "he",                   # Surface text
  type: :pronoun,               # Mention type
  sentence_idx: 1,              # Sentence number
  token_idx: 0,                 # Token position
  gender: :male,                # Gender (male/female/unknown)
  number: :singular,            # Number (singular/plural)
  span: %{...}                  # Position info
}
```

## Complete Pipeline Example

Here's a complete example using all information extraction features:

```elixir
alias Nasty.Language.English.{
  Tokenizer,
  POSTagger,
  Morphology,
  SentenceParser,
  EntityRecognizer,
  RelationExtractor,
  EventExtractor,
  CoreferenceResolver
}

alias Nasty.AST.{Document, Paragraph}

text = \"\"\"
Google acquired YouTube in October 2006 for $1.65 billion.
The company announced the deal in San Francisco.
It was the largest acquisition in Google's history.
\"\"\"

# 1. Parse text into document structure
{:ok, tokens} = Tokenizer.tokenize(text)
{:ok, tagged} = POSTagger.tag_pos(tokens)
{:ok, analyzed} = Morphology.analyze(tagged)
{:ok, sentences} = SentenceParser.parse_sentences(analyzed)

paragraph = %Paragraph{
  sentences: sentences,
  span: %{...},
  language: :en
}

document = %Document{
  paragraphs: [paragraph],
  span: %{...},
  language: :en
}

# 2. Extract entities
entities = EntityRecognizer.recognize(tokens)
# => [%Entity{type: :org, text: "Google"}, ...]

# 3. Extract relations
{:ok, relations} = RelationExtractor.extract(document)
# => [%Relation{type: :acquired_by, subject: youtube, object: google}, ...]

# 4. Extract events  
{:ok, events} = EventExtractor.extract(document)
# => [%Event{type: :business_acquisition, trigger: "acquired", ...}, ...]

# 5. Resolve coreferences
{:ok, chains} = CoreferenceResolver.resolve(document)
# => [%CorefChain{mentions: [google, "the company"], ...}, ...]
```

## Best Practices

### Performance

1. **Reuse tagged tokens**: Parse once, extract multiple times
2. **Set confidence thresholds**: Filter low-confidence results
3. **Limit results**: Use `max_relations`/`max_events` options
4. **Choose appropriate model**: Rule-based for speed, CRF for accuracy

### Accuracy

1. **Use domain-specific lexicons**: Extend entity recognizer with domain terms
2. **Validate results**: Check confidence scores
3. **Combine features**: Use relations + events together for richer extraction
4. **Handle ambiguity**: Month names like "May" can be dates or names

### Common Patterns

```elixir
# Filter high-confidence relations
high_conf = Enum.filter(relations, fn r -> r.confidence > 0.8 end)

# Group events by type
events_by_type = Enum.group_by(events, & &1.type)

# Find entity mentions across coreference chains
all_mentions = Enum.flat_map(chains, & &1.mentions)

# Extract date/time entities
temporal = Enum.filter(entities, fn e -> e.type in [:date, :time] end)
```

## Limitations

### Current Limitations

1. **Numeric patterns**: Years, times with colons, currency symbols not fully supported in rule-based NER
2. **Complex relations**: Multi-hop relations not extracted
3. **Nested events**: Sub-events not represented separately
4. **Cross-document**: Coreference limited to single documents

### Future Enhancements

- Neural NER models for better accuracy
- Transformer-based relation extraction
- Temporal relation extraction (before/after events)
- Cross-document entity linking
- Multi-lingual information extraction

## References

- [docs/PARSING_GUIDE.md](PARSING_GUIDE.md) - Parsing algorithms
- [docs/languages/ENGLISH_GRAMMAR.md](languages/ENGLISH_GRAMMAR.md) - Grammar specification
- [Entity types specification](https://universaldependencies.org/) - Universal Dependencies
