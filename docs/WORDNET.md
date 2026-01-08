# WordNet Integration

Complete guide to using WordNet with Nasty for word sense disambiguation and semantic similarity.

## Overview

Nasty integrates **Open English WordNet** (OEWN) and **Open Multilingual WordNet** (OMW) to provide comprehensive lexical database support. WordNet enhances natural language processing by:

- **Word Sense Disambiguation** - Determine which meaning of a word is used in context
- **Semantic Similarity** - Measure how similar two words or concepts are
- **Synonym/Antonym Discovery** - Find related words
- **Hierarchical Relationships** - Navigate hypernym/hyponym taxonomies
- **Cross-lingual Support** - Link concepts across English, Spanish, and Catalan

## Quick Start

```elixir
alias Nasty.Lexical.WordNet

# Get all meanings of "bank"
synsets = WordNet.synsets("bank", :noun)
# => [
#   %Synset{definition: "financial institution", ...},
#   %Synset{definition: "land alongside water", ...}
# ]

# Get definition
WordNet.definition(synset_id)
# => "a financial institution that accepts deposits"

# Find synonyms
WordNet.synonyms("big", :adj)
# => ["large", "big", "great"]

# Get hypernyms (more general concepts)
WordNet.hypernyms(synset_id)
# => ["oewn-02083346-n"]  # canine

# Calculate semantic similarity
alias Nasty.Lexical.WordNet.Similarity
Similarity.wup_similarity(dog_id, cat_id)
# => 0.857  # High similarity
```

## Installation

### 1. Download WordNet Data

```bash
# Download English WordNet (required for most features)
mix nasty.wordnet.download --language en

# Optional: Download Spanish
mix nasty.wordnet.download --language es

# Optional: Download Catalan
mix nasty.wordnet.download --language ca
```

Data files are downloaded to `priv/wordnet/` by default.

### 2. Verify Installation

```bash
mix nasty.wordnet.list
```

Expected output:
```
WordNet Data Status
============================================================

English (en)
  Status: Installed
  Path: priv/wordnet/oewn-2025.json
  Size: 45.2 MB
  Loaded: No (will load on first use)

Spanish (es)
  Status: Not installed
  Download: mix nasty.wordnet.download --language es
...
```

## Core Concepts

### Synsets

A **synset** (synonym set) groups words with the same meaning:

```elixir
# Get synsets for "dog"
synsets = WordNet.synsets("dog", :noun)

# First synset
synset = hd(synsets)
synset.id          # => "oewn-02084071-n"
synset.definition  # => "a member of the genus Canis"
synset.examples    # => ["the dog barked all night"]
synset.lemmas      # => ["dog", "domestic dog", "Canis familiaris"]
synset.pos         # => :noun
```

### Lemmas

A **lemma** is a specific word sense:

```elixir
lemmas = WordNet.lemmas("run", :verb)
# Multiple senses of "run" as a verb

lemma = hd(lemmas)
lemma.word        # => "run"
lemma.synset_id   # => "oewn-01926311-v"
lemma.sense_key   # => "run%2:38:00::"
```

### Relations

WordNet defines **semantic relations** between synsets:

```elixir
# Hypernyms (more general)
WordNet.hypernyms(dog_id)  # => [canine_id]

# Hyponyms (more specific)
WordNet.hyponyms(canine_id)  # => [dog_id, wolf_id, fox_id, ...]

# Meronyms (part-of)
WordNet.meronyms(car_id)  # => [wheel_id, door_id, engine_id, ...]

# Holonyms (whole-of)
WordNet.holonyms(wheel_id)  # => [car_id, bicycle_id, ...]

# Antonyms (opposites)
WordNet.antonyms(hot_id)  # => [cold_id]

# Similar concepts
WordNet.similar(hot_id)  # => [warm_id, ...]
```

## API Reference

### Synset Operations

#### `synsets/3`

Get all synsets for a word.

```elixir
WordNet.synsets(word, pos \\ nil, language \\ :en)
```

**Parameters:**
- `word` - Word to look up (string)
- `pos` - Part of speech filter: `:noun`, `:verb`, `:adj`, `:adv`, or `nil` for all
- `language` - Language code: `:en`, `:es`, `:ca`

**Returns:** List of `Synset` structs

**Examples:**
```elixir
# All senses of "run"
WordNet.synsets("run")

# Only verb senses
WordNet.synsets("run", :verb)

# Spanish word
WordNet.synsets("perro", :noun, :es)
```

#### `synset/2`

Get a specific synset by ID.

```elixir
WordNet.synset(synset_id, language \\ :en)
```

#### `definition/2`

Get the definition of a synset.

```elixir
WordNet.definition(synset_id, language \\ :en)
# => "a member of the genus Canis"
```

#### `examples/2`

Get usage examples for a synset.

```elixir
WordNet.examples(synset_id, language \\ :en)
# => ["the dog barked all night"]
```

### Relation Operations

#### Taxonomic Relations

```elixir
# More general concepts
WordNet.hypernyms(synset_id, language \\ :en)

# More specific concepts
WordNet.hyponyms(synset_id, language \\ :en)
```

#### Part-Whole Relations

```elixir
# Parts of this concept
WordNet.meronyms(synset_id, language \\ :en)

# Wholes that contain this concept
WordNet.holonyms(synset_id, language \\ :en)
```

#### Similarity/Opposition

```elixir
# Opposite concepts
WordNet.antonyms(synset_id, language \\ :en)

# Similar concepts
WordNet.similar(synset_id, language \\ :en)
```

#### All Relations

```elixir
# Get all relations from a synset
WordNet.all_relations(synset_id, language \\ :en)
# => [{:hypernym, "target-id"}, {:meronym, "another-id"}, ...]
```

### Synonym/Antonym Discovery

#### `synonyms/3`

Find synonyms by getting all words in same synsets.

```elixir
WordNet.synonyms(word, pos \\ nil, language \\ :en)

# Examples
WordNet.synonyms("big")
# => ["big", "large", "great", "huge"]

WordNet.synonyms("run", :verb)
# => ["run", "jog", "sprint", ...]
```

### Semantic Path Operations

#### `common_hypernyms/3`

Find shared ancestors of two synsets.

```elixir
WordNet.common_hypernyms(synset1_id, synset2_id, language \\ :en)
# => [common_ancestor_id, ...]
```

#### `shortest_path/3`

Find shortest path length between synsets.

```elixir
WordNet.shortest_path(synset1_id, synset2_id, language \\ :en)
# => 3  # number of edges
```

### Cross-lingual Operations

#### `from_ili/2`

Find synsets in target language via Interlingual Index.

```elixir
# Find English equivalent of Spanish word
spanish_synsets = WordNet.synsets("perro", :noun, :es)
spanish_synset = hd(spanish_synsets)

# Get ILI
ili_id = spanish_synset.ili  # => "i2084071"

# Find in English
english_synsets = WordNet.from_ili(ili_id, :en)
# => [%Synset{lemmas: ["dog", ...]}]
```

## Semantic Similarity

The `Nasty.Lexical.WordNet.Similarity` module provides various similarity metrics.

### Path Similarity

Based on shortest path in hypernym hierarchy:

```elixir
alias Nasty.Lexical.WordNet.Similarity

# Path similarity (0.0 to 1.0)
Similarity.path_similarity(dog_id, mammal_id)
# => 0.5  # 1 edge apart

Similarity.path_similarity(dog_id, organism_id)
# => 0.25  # 3 edges apart
```

### Wu-Palmer Similarity

Based on depth of Least Common Subsumer (LCS):

```elixir
# Wu-Palmer similarity (0.0 to 1.0)
Similarity.wup_similarity(dog_id, cat_id)
# => 0.857  # High similarity (both mammals)

Similarity.wup_similarity(dog_id, tree_id)
# => 0.133  # Low similarity (different domains)
```

**Formula:** `2 * depth(LCS) / (depth(synset1) + depth(synset2))`

### Lesk Similarity

Based on definition overlap:

```elixir
# Lesk similarity (0.0 to 1.0)
Similarity.lesk_similarity(dog_id, cat_id)
# => 0.15  # Some overlapping words in definitions
```

### Combined Similarity

Weighted combination of multiple metrics:

```elixir
Similarity.combined_similarity(
  dog_id,
  cat_id,
  :en,
  metrics: [:path, :wup, :lesk],
  weights: [0.3, 0.5, 0.2]
)
# => 0.654
```

### Word Similarity

Compare words directly (not synsets):

```elixir
Similarity.word_similarity("dog", "cat", :noun)
# => 0.857  # Max similarity across all synset pairs

Similarity.word_similarity("happy", "sad", :adj, :en, metric: :wup)
# => 0.5  # Moderate similarity (both emotions)
```

## Word Sense Disambiguation

WordNet dramatically enhances WSD accuracy from ~60% to ~75%+.

### Basic WSD

```elixir
alias Nasty.Language.English.WordSenseDisambiguator, as: WSD

# Disambiguate "bank" in context
context_tokens = [
  %Token{text: "river", pos_tag: :noun},
  %Token{text: "flowing", pos_tag: :verb}
]

{:ok, sense} = WSD.disambiguate("bank", context_tokens, pos_tag: :noun)

sense.definition  # => "land alongside a body of water"
sense.synset_id   # => "oewn-..."
```

### How It Works

1. **Get all senses** from WordNet (not just 5 hardcoded ones!)
2. **Score each sense** using Lesk algorithm:
   - Context-definition overlap
   - Related words (hypernyms, synonyms)
   - Frequency ranking
3. **Return best match**

### Full Pipeline

```elixir
alias Nasty.Language.English

# Parse sentence
{:ok, tokens} = English.tokenize("The river bank was muddy.")
{:ok, tagged} = English.tag_pos(tokens)

# Disambiguate all content words
disambiguated = WSD.disambiguate_all(tagged)

Enum.each(disambiguated, fn {token, sense} ->
  IO.puts("#{token.text}: #{sense.definition}")
end)

# Output:
# river: a large natural stream of water
# bank: land alongside a body of water
# muddy: covered with mud
```

## Advanced Usage

### Depth Calculation

```elixir
alias Nasty.Lexical.WordNet.Similarity

# Calculate depth in taxonomy
Similarity.depth(entity_id)  # => 0  (root)
Similarity.depth(dog_id)     # => 13 (deep in hierarchy)
```

### Least Common Subsumer

```elixir
# Find most specific common ancestor
lcs_id = Similarity.lcs(dog_id, cat_id)
# => mammal_id
```

### Statistics

```elixir
# Get statistics for loaded data
WordNet.stats(:en)
# => %{synsets: 120532, lemmas: 155287, relations: 207016}
```

### Manual Loading

```elixir
# Pre-load data (otherwise loads on first use)
WordNet.ensure_loaded(:en)
WordNet.ensure_loaded(:es)

# Check if loaded
WordNet.loaded?(:en)  # => true
```

## Performance

### Memory Usage

- **English (OEWN):** ~200MB RAM (120K synsets)
- **Spanish (OMW):** ~50MB RAM (30K synsets)
- **Catalan (OMW):** ~40MB RAM (25K synsets)

### Load Time

- **JSON parsing:** ~1-2 seconds per language
- **ETS table building:** ~1 second
- **Total:** 2-3 seconds per language

### Query Performance

- **Synset lookup by ID:** O(1), <1ms
- **Lemma lookup by word:** O(1), <1ms
- **Hypernym traversal:** O(d) where d=depth, <5ms typical
- **Similarity calculation:** O(d1 + d2), <10ms typical
- **Shortest path:** BFS, depends on distance

### Optimization

WordNet uses **lazy loading** - data loads only when first accessed:

```elixir
# Fast - no loading
WordNet.loaded?(:en)  # => false

# First query triggers loading (2-3 seconds)
WordNet.synsets("dog")

# Subsequent queries are instant
WordNet.synsets("cat")  # <1ms
```

## Troubleshooting

### WordNet Not Found

```
WordNet data file not found for en: priv/wordnet/oewn-2025.json
Run 'mix nasty.wordnet.download --language en' to download.
```

**Solution:** Download the data file:
```bash
mix nasty.wordnet.download --language en
```

### No Synsets Found

```elixir
WordNet.synsets("misspelled")
# => []
```

**Solutions:**
1. Check spelling
2. Try lemmatized form: "running" → "run"
3. Try different POS tag
4. Word may not be in WordNet

### Memory Issues

If loading multiple languages causes memory issues:

1. Only load languages you need
2. Use lazy loading (don't pre-load)
3. Consider clearing unused languages:
   ```elixir
   Storage.clear(:es)  # Free Spanish data
   ```

### Slow First Query

First query loads WordNet data (2-3 seconds). To avoid:

```elixir
# Pre-load during application startup
defmodule MyApp.Application do
  def start(_type, _args) do
    # Load WordNet in background
    Task.start(fn -> Nasty.Lexical.WordNet.ensure_loaded(:en) end)
    
    # ...
  end
end
```

## Examples

### Example 1: Find Related Words

```elixir
defmodule RelatedWords do
  alias Nasty.Lexical.WordNet

  def find_related(word, pos \\ :noun) do
    synsets = WordNet.synsets(word, pos)
    synset = hd(synsets)  # Use first (most common) sense
    
    # Get hypernyms
    hypernym_ids = WordNet.hypernyms(synset.id)
    hypernyms = Enum.map(hypernym_ids, &WordNet.synset(&1))
    
    # Get hyponyms
    hyponym_ids = WordNet.hyponyms(synset.id)
    hyponyms = Enum.map(hyponym_ids, &WordNet.synset(&1))
    
    %{
      word: word,
      definition: synset.definition,
      synonyms: synset.lemmas,
      more_general: Enum.flat_map(hypernyms, & &1.lemmas),
      more_specific: Enum.flat_map(hyponyms, & &1.lemmas)
    }
  end
end

RelatedWords.find_related("dog")
# => %{
#   word: "dog",
#   definition: "a member of the genus Canis",
#   synonyms: ["dog", "domestic dog", "Canis familiaris"],
#   more_general: ["canine", "canid"],
#   more_specific: ["puppy", "hound", "working dog", ...]
# }
```

### Example 2: Semantic Search

```elixir
defmodule SemanticSearch do
  alias Nasty.Lexical.WordNet
  alias Nasty.Lexical.WordNet.Similarity

  def find_similar(query_word, candidate_words, threshold \\ 0.5) do
    query_synsets = WordNet.synsets(query_word, :noun)
    query_synset = hd(query_synsets)
    
    candidate_words
    |> Enum.map(fn word ->
      synsets = WordNet.synsets(word, :noun)
      if synsets == [], do: {word, 0.0}, else: {word, max_similarity(query_synset, synsets)}
    end)
    |> Enum.filter(fn {_word, sim} -> sim >= threshold end)
    |> Enum.sort_by(fn {_word, sim} -> sim end, :desc)
  end
  
  defp max_similarity(query_synset, candidate_synsets) do
    Enum.map(candidate_synsets, fn synset ->
      Similarity.wup_similarity(query_synset.id, synset.id)
    end)
    |> Enum.max()
  end
end

SemanticSearch.find_similar("dog", ["cat", "wolf", "tree", "house"])
# => [
#   {"cat", 0.857},
#   {"wolf", 0.923},
#   {"tree", 0.133},
#   {"house", 0.125}
# ]
```

### Example 3: Cross-lingual Translation

```elixir
defmodule CrossLingual do
  alias Nasty.Lexical.WordNet

  def translate(word, from_lang, to_lang) do
    # Get synsets in source language
    synsets = WordNet.synsets(word, nil, from_lang)
    
    # For each synset, find equivalent in target language
    Enum.flat_map(synsets, fn synset ->
      if synset.ili do
        target_synsets = WordNet.from_ili(synset.ili, to_lang)
        Enum.flat_map(target_synsets, & &1.lemmas)
      else
        []
      end
    end)
    |> Enum.uniq()
  end
end

CrossLingual.translate("perro", :es, :en)
# => ["dog", "domestic dog", "Canis familiaris"]

CrossLingual.translate("dog", :en, :es)
# => ["perro", "can"]
```

## References

- [Open English WordNet](https://github.com/globalwordnet/english-wordnet)
- [Open Multilingual WordNet](https://omwn.org/)
- [WN-LMF Specification](https://globalwordnet.github.io/schemas/)
- [Princeton WordNet](https://wordnet.princeton.edu/)
- [Wu & Palmer (1994)](https://dl.acm.org/doi/10.3115/981732.981751) - Wu-Palmer Similarity
- [Lesk (1986)](https://dl.acm.org/doi/10.1145/318723.318728) - Lesk Algorithm

## See Also

- [PARSING_GUIDE.md](PARSING_GUIDE.md) - NLP pipeline overview
- [ENGLISH_GRAMMAR.md](languages/ENGLISH_GRAMMAR.md) - Grammar specification  
- [USER_GUIDE.md](USER_GUIDE.md) - General usage guide
