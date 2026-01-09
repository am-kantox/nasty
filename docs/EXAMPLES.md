# Nasty Examples Catalog

Comprehensive catalog of all example scripts demonstrating Nasty's capabilities.

## Quick Start

All examples can be run directly:
```bash
elixir examples/example_name.exs
```

Or make them executable:
```bash
chmod +x examples/example_name.exs
./examples/example_name.exs
```

## Basic Examples

### tokenizer_example.exs

**Purpose**: Introduction to tokenization

**What it demonstrates**:
- Basic tokenization with NimbleParsec
- Position tracking (line, column, byte offsets)
- Handling contractions (don't, it's)
- Punctuation as separate tokens
- Sentence boundary detection

**Run**:
```bash
elixir examples/tokenizer_example.exs
```

**Best for**: Understanding the first step in the NLP pipeline

---

### hmm_pos_tagger_example.exs

**Purpose**: Statistical POS tagging with Hidden Markov Models

**What it demonstrates**:
- Training HMM POS taggers from CoNLL-U data
- Viterbi algorithm for sequence tagging
- Model evaluation and accuracy metrics
- Comparison with rule-based tagging
- Model persistence (save/load)

**Run**:
```bash
elixir examples/hmm_pos_tagger_example.exs
```

**Best for**: Learning about statistical NLP models

---

### neural_pos_tagger_example.exs

**Purpose**: Neural POS tagging with BiLSTM-CRF

**What it demonstrates**:
- BiLSTM-CRF architecture with Axon/EXLA
- Training neural models on UD corpora
- Character-level embeddings for OOV handling
- GPU acceleration with EXLA
- 97-98% accuracy on benchmark datasets

**Run**:
```bash
elixir examples/neural_pos_tagger_example.exs
```

**Best for**: Understanding deep learning for NLP

---

## Language-Specific Examples

### spanish_example.exs

**Purpose**: Spanish language processing

**What it demonstrates**:
- Spanish tokenization (¿?, ¡!, del, al contractions)
- Spanish POS tagging with morphology
- Gender/number agreement
- Parsing Spanish sentence structure
- Entity recognition with Spanish lexicons

**Run**:
```bash
elixir examples/spanish_example.exs
```

**Best for**: Working with Romance languages

---

### catalan_example.exs

**Purpose**: Catalan language processing  

**What it demonstrates**:
- Catalan-specific tokenization (interpunct l·l, apostrophes)
- All 10 Catalan diacritics (à, è, é, í, ï, ò, ó, ú, ü, ç)
- Article contractions (del, al, pel, cal)
- Catalan morphology and POS tagging
- Entity recognition with Catalan lexicons
- Translation between Catalan and English

**Run**:
```bash
elixir examples/catalan_example.exs
```

**Best for**: Catalan NLP applications

---

## Translation Examples

### translation_example.exs

**Purpose**: Basic AST-based translation

**What it demonstrates**:
- English ↔ Spanish translation
- AST-level translation preserving grammar
- Morphological agreement enforcement
- Word order transformations
- Rendering translated AST to text

**Run**:
```bash
elixir examples/translation_example.exs
```

**Best for**: Getting started with translation

---

### roundtrip_translation.exs

**Purpose**: Translation quality analysis

**What it demonstrates**:
- English → Spanish → English roundtrips
- English → Catalan → English roundtrips
- Spanish → English → Spanish roundtrips
- Similarity metrics and quality assessment
- Challenging translation cases
- Performance across complexity levels

**Run**:
```bash
elixir examples/roundtrip_translation.exs
```

**Best for**: Evaluating translation quality

---

### multilingual_pipeline.exs

**Purpose**: Side-by-side multilingual comparison

**What it demonstrates**:
- Processing same content in English, Spanish, Catalan
- Token-level comparison across languages
- POS tagging differences
- Morphological feature comparison
- Translation matrix (all language pairs)
- Performance benchmarking
- Language-specific features summary

**Run**:
```bash
elixir examples/multilingual_pipeline.exs
```

**Best for**: Understanding cross-language differences

---

## Advanced NLP Tasks

### summarization.exs

**Purpose**: Extractive text summarization

**What it demonstrates**:
- Position-weighted sentence scoring
- Entity density calculation
- Discourse marker detection
- Keyword frequency (TF)
- MMR (Maximal Marginal Relevance) for diversity
- Compression ratio vs. fixed sentence count

**Run**:
```bash
elixir examples/summarization.exs
```

**Best for**: Document summarization applications

---

### question_answering.exs

**Purpose**: Extractive question answering

**What it demonstrates**:
- Question classification (WHO, WHAT, WHEN, WHERE, WHY, HOW)
- Answer extraction strategies
- Entity type filtering
- Keyword matching with lemmatization
- Confidence scoring
- Multiple answer support

**Run**:
```bash
elixir examples/question_answering.exs
```

**Best for**: Building Q&A systems

---

### text_classification.exs

**Purpose**: Document classification

**What it demonstrates**:
- Multinomial Naive Bayes classifier
- Feature extraction (BOW, n-grams, POS patterns, entities, lexical)
- Training on labeled data
- Multi-class classification
- Model evaluation (accuracy, precision, recall, F1)
- Sentiment analysis example

**Run**:
```bash
elixir examples/text_classification.exs
```

**Best for**: Text categorization tasks

---

### information_extraction.exs

**Purpose**: Structured information extraction

**What it demonstrates**:
- Relation extraction (employment, organization, location)
- Event extraction (acquisitions, foundings, announcements)
- Template-based extraction
- Pattern matching with verb patterns
- Confidence scoring
- Integration with NER and dependencies

**Run**:
```bash
elixir examples/information_extraction.exs
```

**Best for**: Knowledge base construction

---

## Code Interoperability

### code_generation.exs

**Purpose**: Natural language to code

**What it demonstrates**:
- Intent recognition from natural language
- Constraint extraction (comparison, property, range)
- Elixir code generation
- List operations (sort, filter, map, reduce)
- Arithmetic expressions
- Conditional statements

**Run**:
```bash
elixir examples/code_generation.exs
```

**Best for**: Natural language programming interfaces

---

### code_explanation.exs

**Purpose**: Code to natural language

**What it demonstrates**:
- Elixir AST parsing
- Code explanation generation
- Pipeline explanation
- Function call description
- Variable usage analysis

**Run**:
```bash
elixir examples/code_explanation.exs
```

**Best for**: Code documentation and understanding

---

## Neural Network Examples

### pretrained_model_usage.exs

**Purpose**: Using pre-trained transformers

**What it demonstrates**:
- BERT and RoBERTa via Bumblebee
- Fine-tuning for POS tagging and NER
- Zero-shot classification
- Model quantization (INT8)
- Multilingual models (XLM-RoBERTa)

**Run**:
```bash
elixir examples/pretrained_model_usage.exs
```

**Best for**: Leveraging pre-trained models

---

### transformer_pos_example.exs

**Purpose**: Transformer-based POS tagging

**What it demonstrates**:
- RoBERTa for POS tagging
- Fine-tuning transformers
- 98-99% accuracy
- Cross-lingual transfer
- Model comparison

**Run**:
```bash
elixir examples/transformer_pos_example.exs
```

**Best for**: State-of-the-art accuracy

---

### advanced_neural_features.exs

**Purpose**: Advanced neural NLP features

**What it demonstrates**:
- Multiple neural architectures
- Ensemble methods
- Model quantization
- Zero-shot learning
- Cross-lingual transfer
- Performance optimization

**Run**:
```bash
elixir examples/advanced_neural_features.exs
```

**Best for**: Production neural NLP systems

---

## Comprehensive Demos

### comprehensive_demo.exs

**Purpose**: Complete NLP pipeline walkthrough

**What it demonstrates**:
- Full pipeline from tokenization to summarization
- All major NLP tasks
- Entity recognition
- Dependency extraction
- Semantic role labeling
- Coreference resolution
- Information extraction

**Run**:
```bash
./examples/comprehensive_demo.exs
```

**Best for**: Overview of all capabilities

---

## Example Selection Guide

### By Use Case

**Text Analysis**:
- tokenizer_example.exs
- hmm_pos_tagger_example.exs
- comprehensive_demo.exs

**Machine Learning**:
- neural_pos_tagger_example.exs
- transformer_pos_example.exs
- text_classification.exs
- advanced_neural_features.exs

**Multilingual**:
- spanish_example.exs
- catalan_example.exs
- translation_example.exs
- roundtrip_translation.exs
- multilingual_pipeline.exs

**Information Extraction**:
- question_answering.exs
- information_extraction.exs
- summarization.exs

**Code Integration**:
- code_generation.exs
- code_explanation.exs

### By Difficulty Level

**Beginner**:
1. tokenizer_example.exs
2. spanish_example.exs
3. translation_example.exs
4. summarization.exs

**Intermediate**:
1. hmm_pos_tagger_example.exs
2. catalan_example.exs
3. question_answering.exs
4. text_classification.exs
5. multilingual_pipeline.exs

**Advanced**:
1. neural_pos_tagger_example.exs
2. information_extraction.exs
3. transformer_pos_example.exs
4. advanced_neural_features.exs
5. roundtrip_translation.exs

### By Processing Time

**Fast (<1 second)**:
- tokenizer_example.exs
- translation_example.exs
- spanish_example.exs

**Medium (1-10 seconds)**:
- catalan_example.exs
- multilingual_pipeline.exs
- summarization.exs
- question_answering.exs

**Slow (>10 seconds)**:
- hmm_pos_tagger_example.exs (if training)
- neural_pos_tagger_example.exs
- transformer_pos_example.exs
- roundtrip_translation.exs

## Running Multiple Examples

### Run all basic examples:
```bash
for example in tokenizer_example spanish_example translation_example; do
  echo "Running ${example}..."
  elixir examples/${example}.exs
  echo "---"
done
```

### Run all translation examples:
```bash
for example in translation_example roundtrip_translation multilingual_pipeline; do
  elixir examples/${example}.exs
done
```

### Run all language-specific examples:
```bash
elixir examples/spanish_example.exs
elixir examples/catalan_example.exs
elixir examples/multilingual_pipeline.exs
```

## Expected Output

### Typical Output Format

Most examples output:
1. **Section headers**: Clearly marked sections
2. **Input text**: What's being processed
3. **Results**: Parsed output, tags, entities, etc.
4. **Statistics**: Counts, accuracy, timing
5. **Summary**: Key takeaways

### Example Output Snippet

```
========================================
Spanish Language Processing Demo
========================================

1. Tokenization
---------------
Input: El gato duerme en el sofá.

Tokens:
  El (1:1)
  gato (1:4)
  duerme (1:9)
  ...

2. POS Tagging
--------------
Tagged tokens:
  El → det
  gato → noun
  duerme → verb
  ...
```

## Troubleshooting

### Common Issues

**Example won't run**:
```bash
# Make sure dependencies are installed
mix deps.get
mix compile

# Check file permissions
chmod +x examples/example_name.exs
```

**Missing models**:
Some examples (neural, transformer) require trained models. See [TRAINING_NEURAL.md](TRAINING_NEURAL.md) for training instructions.

**Out of memory**:
Neural/transformer examples may need more memory. Reduce batch size or use smaller models.

## Creating Your Own Examples

Template for new examples:

```elixir
#!/usr/bin/env elixir

# Your Example Name
#
# Brief description of what this example demonstrates

Mix.install([
  {:nasty, path: Path.expand("..", __DIR__)}
])

alias Nasty.Language.English

IO.puts("\n========================================")
IO.puts("Your Example Title")
IO.puts("========================================\n")

# Example 1: First concept
IO.puts("1. First Section")
IO.puts("----------------")

# Your code here

# Example 2: Second concept
IO.puts("\n2. Second Section")
IO.puts("-----------------")

# Your code here

IO.puts("\n========================================")
IO.puts("Example Complete!")
IO.puts("========================================\n")
```

## See Also

- [GETTING_STARTED.md](GETTING_STARTED.md) - Tutorial for beginners
- [USER_GUIDE.md](USER_GUIDE.md) - Comprehensive usage guide
- [API.md](API.md) - API reference
- [TRANSLATION.md](TRANSLATION.md) - Translation system guide
