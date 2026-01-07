# Statistical Models Guide

This document provides a comprehensive guide to the advanced statistical models implemented in Nasty: **PCFG (Probabilistic Context-Free Grammar)** for parsing and **CRF (Conditional Random Fields)** for sequence labeling/NER.

## Overview

Nasty implements two major classes of statistical models:

1. **PCFG Parser** - For probabilistic phrase structure parsing with ambiguity resolution
2. **CRF-based NER** - For context-aware named entity recognition using sequence labeling

Both models follow the `Nasty.Statistics.Model` behaviour, providing consistent interfaces for training, prediction, and persistence.

## PCFG (Probabilistic Context-Free Grammar)

### What is PCFG?

PCFG extends traditional context-free grammars with probabilities on production rules. This allows the parser to:
- Resolve syntactic ambiguities probabilistically
- Score different parse trees and select the most likely one
- Handle rare constructions gracefully through smoothing

### Architecture

**Core Modules:**
- `Nasty.Statistics.Parsing.Grammar` - Rule representation and CNF conversion
- `Nasty.Statistics.Parsing.CYKParser` - CYK parsing algorithm
- `Nasty.Statistics.Parsing.PCFG` - Main model implementing `Model` behaviour

**Data Flow:**
```
Training Data (Treebank)
    ↓
Extract Grammar Rules + Probabilities
    ↓
CNF Conversion
    ↓
Trained PCFG Model
    ↓
CYK Parser (Viterbi)
    ↓
Parse Tree with Probability
```

### Grammar Rules

PCFG uses production rules with probabilities:

```
NP → Det Noun     [0.35]
NP → PropN        [0.25]
VP → Verb NP      [0.45]
```

The sum of probabilities for all rules with the same left-hand side equals 1.0.

### CYK Algorithm

The Cocke-Younger-Kasami algorithm:
1. Requires grammar in Chomsky Normal Form (CNF)
2. Uses dynamic programming (O(n³) complexity)
3. Fills a chart bottom-up
4. Extracts highest probability parse tree

**Complexity:**
- Time: O(n³ × |G|) where n = sentence length, |G| = grammar size
- Space: O(n² × |G|)

### Training

Train PCFG from Universal Dependencies treebanks or raw grammar rules:

```elixir
# From raw rules
training_data = [
  {:np, [:det, :noun], 350},  # Count: 350 occurrences
  {:np, [:propn], 250},
  {:vp, [:verb, :np], 450}
]

model = PCFG.new()
{:ok, trained} = PCFG.train(model, training_data, smoothing: 0.001)
:ok = PCFG.save(trained, "priv/models/en/pcfg.model")
```

### Prediction

Parse sentences to get probabilistic parse trees:

```elixir
{:ok, model} = PCFG.load("priv/models/en/pcfg.model")
tokens = [%Token{text: "the", pos_tag: :det}, %Token{text: "cat", pos_tag: :noun}]
{:ok, parse_tree} = PCFG.predict(model, tokens)

# Parse tree contains:
# - label: :np
# - probability: 0.0245
# - children: [...]
# - span: {0, 1}
```

### N-Best Parsing

Get multiple parse hypotheses:

```elixir
{:ok, trees} = PCFG.predict(model, tokens, n_best: 5)
# Returns top 5 parse trees sorted by probability
```

### Evaluation

Compute bracketing precision/recall/F1:

```elixir
test_data = [{tokens, gold_tree}, ...]
metrics = PCFG.evaluate(model, test_data)
# %{precision: 0.87, recall: 0.85, f1: 0.86, exact_match: 0.42}
```

### Mix Tasks

```bash
# Train PCFG from UD treebank
mix nasty.train.pcfg \
  --corpus data/en_ewt-ud-train.conllu \
  --output priv/models/en/pcfg.model \
  --smoothing 0.001

# Evaluate PCFG
mix nasty.eval.pcfg \
  --model priv/models/en/pcfg.model \
  --test data/en_ewt-ud-test.conllu
```

## CRF (Conditional Random Fields)

### What is CRF?

CRFs are discriminative models for sequence labeling that consider:
- Rich feature sets (lexical, orthographic, contextual)
- Label dependencies (transition probabilities)
- Global normalization (partition function)

Unlike HMMs, CRFs can handle overlapping features and don't make independence assumptions.

### Architecture

**Core Modules:**
- `Nasty.Statistics.SequenceLabeling.Features` - Feature extraction
- `Nasty.Statistics.SequenceLabeling.Viterbi` - Decoding algorithm
- `Nasty.Statistics.SequenceLabeling.Optimizer` - Gradient descent training
- `Nasty.Statistics.SequenceLabeling.CRF` - Main model implementing `Model` behaviour

**Data Flow:**
```
Tokens + Labels (Training)
    ↓
Feature Extraction
    ↓
Forward-Backward (Gradient Computation)
    ↓
Gradient Descent Optimization
    ↓
Trained CRF Model
    ↓
Viterbi Decoding
    ↓
Label Sequence
```

### Feature Extraction

CRFs use rich feature sets extracted from tokens:

**Lexical Features:**
- word, word_lower, lemma

**Orthographic Features:**
- capitalized, all_caps, word_shape (Xxxx, XXX, ddd)
- has_digit, has_hyphen, has_punctuation

**POS Features:**
- pos_tag

**Context Features:**
- prev_word, next_word
- prev_pos, next_pos  
- is_first, is_last

**Affix Features:**
- prefix-1, prefix-2, ..., prefix-4
- suffix-1, suffix-2, ..., suffix-4

**Gazetteer Features:**
- in_gazetteer=person/place/org

**Pattern Features:**
- pattern=all_digits, pattern=year, pattern=acronym
- short_word, long_word

### Model

Linear-chain CRF:
```
P(y|x) = exp(score(x, y)) / Z(x)

score(x, y) = Σ feature_weights + Σ transition_weights
```

Where:
- `feature_weights`: Map of (feature, label) → weight
- `transition_weights`: Map of (prev_label, curr_label) → weight
- `Z(x)`: Partition function (normalization)

### Training

Train CRF on BIO-tagged sequences:

```elixir
# BIO tagging: B-PER, I-PER, B-GPE, I-GPE, B-ORG, I-ORG, O
training_data = [
  {
    [%Token{text: "John"}, %Token{text: "Smith"}],
    [:b_per, :i_per]
  },
  ...
]

model = CRF.new(labels: [:b_per, :i_per, :b_gpe, :i_gpe, :b_org, :i_org, :o])
{:ok, trained} = CRF.train(model, training_data,
  iterations: 100,
  learning_rate: 0.1,
  regularization: 1.0
)
:ok = CRF.save(trained, "priv/models/en/crf_ner.model")
```

**Training Options:**
- `:iterations` - Maximum iterations (default: 100)
- `:learning_rate` - Initial learning rate (default: 0.1)
- `:regularization` - L2 regularization (default: 1.0)
- `:method` - `:sgd`, `:momentum`, `:adagrad` (default: `:momentum`)
- `:convergence_threshold` - Gradient norm threshold (default: 0.01)

### Prediction

Label sequences using Viterbi decoding:

```elixir
{:ok, model} = CRF.load("priv/models/en/crf_ner.model")
tokens = [%Token{text: "John"}, %Token{text: "lives"}, %Token{text: "in"}, %Token{text: "NYC"}]
{:ok, labels} = CRF.predict(model, tokens)
# [:b_per, :o, :o, :b_gpe]
```

### Viterbi Algorithm

Find most likely label sequence:
1. Initialize scores for first position
2. For each subsequent position:
   - Compute emission score (from features)
   - Compute transition score (from previous label)
   - Track best previous label (backpointer)
3. Backtrack from best final label

**Complexity:**
- Time: O(n × L²) where n = sequence length, L = number of labels
- Space: O(n × L)

### Forward-Backward Algorithm

Used during training to compute gradients:
- **Forward**: P(label at position t | observations up to t)
- **Backward**: P(observations after t | label at t)
- **Partition Function**: Z(x) = sum over all label sequences

### Optimization

Gradient descent with momentum:
```
Gradient = Observed Features - Expected Features
Weight Update: w := w - learning_rate * (gradient + regularization * w)
Momentum: v := momentum * v + gradient
```

### Mix Tasks

```bash
# Train CRF NER
mix nasty.train.crf_ner \
  --corpus data/ner_train.conllu \
  --output priv/models/en/crf_ner.model \
  --iterations 100 \
  --learning-rate 0.1 \
  --regularization 1.0

# Evaluate NER
mix nasty.eval.ner \
  --model priv/models/en/crf_ner.model \
  --test data/ner_test.conllu
```

## Integration with English Pipeline

Both models integrate seamlessly with the existing English module:

### PCFG Integration

```elixir
# Mode selection
English.parse(tokens, mode: :pcfg, model_path: "priv/models/en/pcfg.model")
# Falls back to rule-based if mode not specified
```

### CRF Integration

```elixir
# Mode selection for NER
English.recognize_entities(tokens, mode: :crf, model_path: "priv/models/en/crf_ner.model")
# Falls back to rule-based if mode not specified or model unavailable
```

## Performance Expectations

### PCFG Parser

**Accuracy:**
- Bracketing F1: 85-90% on UD test sets
- Higher than rule-based parsing for ambiguous structures

**Speed:**
- ~50-100ms per sentence (CPU)
- Depends on sentence length and grammar size

**Memory:**
- ~50-100MB model file
- O(n²) space during parsing

### CRF-based NER

**Accuracy:**
- Entity-level F1: 92-95% (vs 70-80% rule-based)
- Proper boundary detection
- Better handling of unseen entities

**Speed:**
- ~20-30ms per sentence (CPU)
- Linear in sequence length

**Memory:**
- ~20-50MB model file (depends on feature set)
- O(n) space during decoding

## Comparison with Other Approaches

### PCFG vs Rule-based Parsing

| Aspect | PCFG | Rule-based |
|--------|------|------------|
| Ambiguity | Probabilistic resolution | Greedy heuristics |
| Unknown structures | Graceful degradation | May fail |
| Training | Requires treebank | None needed |
| Speed | Slower (O(n³)) | Faster (O(n)) |
| Accuracy | Higher on complex sentences | Good for simple sentences |

### CRF vs Rule-based NER

| Aspect | CRF | Rule-based |
|--------|-----|------------|
| Context | Global sequence context | Local patterns |
| Features | Rich feature sets | Limited to POS + patterns |
| Boundaries | Learned from data | Heuristic rules |
| Training | Requires annotated data | None needed |
| Unseen entities | Better generalization | Pattern matching only |
| Accuracy | 92-95% F1 | 70-80% F1 |

## Best Practices

### For PCFG

1. **Training Data**: Use high-quality treebanks (UD, Penn Treebank)
2. **Smoothing**: Use add-k smoothing (k=0.001) for unseen rules
3. **CNF Conversion**: Always convert to CNF before parsing
4. **Beam Search**: Use beam width 10-20 for efficiency
5. **Evaluation**: Report bracketing F1, not just accuracy

### For CRF

1. **Features**: Start with full feature set, prune if needed
2. **Regularization**: Use L2 (λ=1.0) to prevent overfitting
3. **Learning Rate**: Start with 0.1, decay if not converging
4. **BIO Tagging**: Always use BIO scheme for proper boundaries
5. **Gazetteers**: Include domain-specific entity lists
6. **Iterations**: 100-200 iterations usually sufficient

## Troubleshooting

### PCFG Issues

**Problem**: Parse fails (returns :error)
- **Solution**: Check if all words have lexical rules; add unknown word handling

**Problem**: Low parsing F1
- **Solution**: Increase training data; adjust smoothing; check CNF conversion

**Problem**: Slow parsing
- **Solution**: Reduce beam width; prune low-probability rules

### CRF Issues

**Problem**: Training doesn't converge
- **Solution**: Reduce learning rate; increase regularization; check gradient computation

**Problem**: Low NER F1
- **Solution**: Add more features; increase training data; check BIO tagging consistency

**Problem**: Slow training
- **Solution**: Reduce feature set; use AdaGrad; parallelize if possible

## Future Enhancements

### PCFG

- Lexicalized PCFG (head-driven)
- Latent variable PCFG
- Neural PCFG with embeddings
- Dependency conversion from CFG parse

### CRF

- Higher-order CRF (beyond linear-chain)
- Semi-Markov CRF for multi-token entities
- Structured perceptron as alternative
- Neural CRF with BiLSTM features

## References

### PCFG

- Charniak, E. (1997). Statistical Parsing with a Context-Free Grammar and Word Statistics
- Klein & Manning (2003). Accurate Unlexicalized Parsing
- Petrov et al. (2006). Learning Accurate, Compact, and Interpretable Tree Annotation

### CRF

- Lafferty et al. (2001). Conditional Random Fields: Probabilistic Models for Segmenting and Labeling Sequence Data
- Sutton & McCallum (2012). An Introduction to Conditional Random Fields
- Tjong Kim Sang & De Meulder (2003). Introduction to the CoNLL-2003 Shared Task: Language-Independent Named Entity Recognition

## Related Documentation

- [ROADMAP.md](ROADMAP.md) - Development roadmap and priorities
- [NEURAL_MODELS.md](NEURAL_MODELS.md) - Neural network architectures (BiLSTM-CRF)
- [TRAINING_NEURAL.md](TRAINING_NEURAL.md) - Neural model training guide
- [PARSING_GUIDE.md](PARSING_GUIDE.md) - Comprehensive parsing documentation
- [WARP.md](../WARP.md) - Command reference for training and evaluation
