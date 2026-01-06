# Statistical Models for Improved Accuracy

This document describes the statistical machine learning models available in Nasty for improved NLP accuracy.

## Overview

Nasty now supports both **rule-based** and **statistical** approaches for NLP tasks:

- **Rule-based** (default): Fast, deterministic, no training required
- **Statistical** (HMM, etc.): Higher accuracy, requires training data
- **Ensemble**: Combines both approaches for best results

## Features

### Currently Implemented

- ✅ HMM POS Tagger with Viterbi decoding
- ✅ CoNLL-U corpus loader (Universal Dependencies format)
- ✅ Training/evaluation infrastructure
- ✅ Feature extraction utilities
- ✅ Model persistence (save/load)
- ✅ Evaluation metrics (accuracy, precision, recall, F1)

### Roadmap

- ⏳ PCFG parser for phrase structure
- ⏳ CRF for named entity recognition
- ⏳ Pre-trained models for English

## Quick Start: Using the Training Script

The easiest way to train a model is using the provided script:

```bash
# 1. Download Universal Dependencies English-EWT
mkdir -p data
cd data
wget https://github.com/UniversalDependencies/UD_English-EWT/archive/refs/tags/r2.13.tar.gz
tar -xzf r2.13.tar.gz
cd ..

# 2. Train the model
./scripts/train_pos_tagger.exs \
  --corpus data/UD_English-EWT-r2.13/en_ewt-ud-train.conllu \
  --dev data/UD_English-EWT-r2.13/en_ewt-ud-dev.conllu \
  --test data/UD_English-EWT-r2.13/en_ewt-ud-test.conllu \
  --output priv/models/en/pos_hmm.model

# Expected: ~95% accuracy on test set in ~30 seconds

# 3. Use your trained model
{:ok, model} = Nasty.Statistics.POSTagging.HMMTagger.load("priv/models/en/pos_hmm.model")
{:ok, ast} = Nasty.parse("The cat sat.", language: :en, model: :hmm, hmm_model: model)
```

For detailed training instructions, see [TRAINING_GUIDE.md](TRAINING_GUIDE.md).

## Quick Start: Programmatic Training

### 1. Training an HMM POS Tagger

```elixir
alias Nasty.Statistics.POSTagging.HMMTagger
alias Nasty.Data.{Corpus, CoNLLU}

# Load training data (Universal Dependencies format)
{:ok, corpus} = Corpus.load_ud("path/to/en_ewt-ud-train.conllu")

# Split into train/validation/test
{train, dev, test} = Corpus.split(corpus, ratios: [0.8, 0.1, 0.1])

# Extract POS tagging sequences
training_data = Corpus.extract_pos_sequences(train)

# Train the model
model = HMMTagger.new(smoothing_k: 0.001)
{:ok, trained_model} = HMMTagger.train(model, training_data, [])

# Save the trained model
:ok = HMMTagger.save(trained_model, "priv/models/en/pos_hmm.model")
```

### 2. Using a Trained Model

```elixir
# Load the model
{:ok, hmm_model} = HMMTagger.load("priv/models/en/pos_hmm.model")

# Parse text with the HMM model
{:ok, ast} = Nasty.parse("The cat sat on the mat.", 
  language: :en,
  model: :hmm,
  hmm_model: hmm_model
)

# Or use ensemble mode (rule-based + HMM)
{:ok, ast} = Nasty.parse("The cat sat on the mat.", 
  language: :en,
  model: :ensemble,
  hmm_model: hmm_model
)
```

### 3. Evaluating Model Accuracy

```elixir
alias Nasty.Statistics.Evaluator

# Extract test data
test_data = Corpus.extract_pos_sequences(test)

# Make predictions
predictions = 
  Enum.map(test_data, fn {words, gold_tags} ->
    {:ok, pred_tags} = HMMTagger.predict(trained_model, words, [])
    {gold_tags, pred_tags}
  end)

# Flatten to token level
gold = predictions |> Enum.flat_map(&elem(&1, 0))
pred = predictions |> Enum.flat_map(&elem(&1, 1))

# Calculate metrics
metrics = Evaluator.classification_metrics(gold, pred)

IO.puts "Accuracy: #{Float.round(metrics.accuracy, 3)}"
IO.puts "F1 Score: #{Float.round(metrics.f1, 3)}"

# Print detailed report
Evaluator.print_report(metrics)
Evaluator.print_confusion_matrix(metrics.confusion_matrix)
```

## Architecture

### Statistical Layer

```
Nasty.Statistics
├── Model (behaviour)           # Common interface for all models
├── FeatureExtractor            # Feature engineering utilities
├── Evaluator                   # Metrics and evaluation
├── POSTagging/
│   └── HMMTagger               # HMM with Viterbi algorithm
├── Parsing/                    # (Future: PCFG, etc.)
└── NER/                        # (Future: CRF, etc.)
```

### Data Layer

```
Nasty.Data
├── CoNLLU                      # Universal Dependencies parser
└── Corpus                      # Corpus loading and management
```

## Model Details

### HMM POS Tagger

**Algorithm**: Hidden Markov Model with Viterbi decoding

**Features**:
- Trigram transitions: P(tag_i | tag_{i-1}, tag_{i-2})
- Emission probabilities: P(word | tag)
- Add-k smoothing for unknown words
- Log-space computation to avoid underflow

**Performance** (typical on UD-EWT):
- Training: ~30 seconds on 12k sentences
- Inference: ~1ms per sentence
- Accuracy: ~95% (vs ~85% rule-based)
- Model size: ~5-10 MB

**Hyperparameters**:
- `smoothing_k`: Smoothing constant (default: 0.001)
  - Higher values = more smoothing = better for OOV words
  - Lower values = sharper distributions = better for known words

## Training Data

### Universal Dependencies

The recommended training data format is CoNLL-U from [Universal Dependencies](https://universaldependencies.org/).

**For English**, download:
- en_ewt-ud-train.conllu
- en_ewt-ud-dev.conllu
- en_ewt-ud-test.conllu

**CoNLL-U Format**:
```
# sent_id = 1
# text = The cat sat.
1    The     the    DET   DT   _   2   det    _   _
2    cat     cat    NOUN  NN   _   3   nsubj  _   _
3    sat     sit    VERB  VBD  _   0   root   _   SpaceAfter=No
4    .       .      PUNCT .    _   3   punct  _   _

```

Each line represents a token with 10 tab-separated fields:
1. ID, 2. FORM (word), 3. LEMMA, 4. UPOS (Universal POS), 5. XPOS, 
6. FEATS, 7. HEAD, 8. DEPREL, 9. DEPS, 10. MISC

## Evaluation Metrics

### POS Tagging

```elixir
metrics = Evaluator.classification_metrics(gold_tags, pred_tags)

# Available metrics:
# - accuracy: Overall token accuracy
# - precision: Per-class precision (macro-averaged)
# - recall: Per-class recall
# - f1: F1 score
# - per_class: Detailed per-tag metrics
# - confusion_matrix: Tag confusion matrix
```

### NER (Future)

```elixir
# Entity-level evaluation (exact match)
metrics = Evaluator.entity_metrics(gold_entities, pred_entities)
# => %{precision: 0.87, recall: 0.85, f1: 0.86}
```

## Feature Extraction

The `FeatureExtractor` module provides rich features for ML models:

```elixir
alias Nasty.Statistics.FeatureExtractor

# Extract features for a token in context
features = FeatureExtractor.extract_all(tokens, index, window: 2)

# => %{
#   word: "running",
#   lowercase: "running",
#   is_capitalized: false,
#   prefix_1: "r", prefix_2: "ru", prefix_3: "run",
#   suffix_1: "g", suffix_2: "ng", suffix_3: "ing",
#   prev_word_1: "was",
#   prev_pos_1: :aux,
#   next_word_1: "fast",
#   ...
# }
```

**Feature Types**:
- Lexical: word form, lowercase, length
- Morphological: prefixes, suffixes, character n-grams
- Orthographic: capitalization, digits, punctuation
- Contextual: surrounding words and POS tags
- Positional: position in sentence

## Advanced Usage

### Custom Training

```elixir
# Prepare your own training data
training_data = [
  {["The", "dog", "barks"], [:det, :noun, :verb]},
  {["A", "cat", "meows"], [:det, :noun, :verb]},
  # ... more examples
]

# Train with custom smoothing
model = HMMTagger.new(smoothing_k: 0.01)
{:ok, trained} = HMMTagger.train(model, training_data, [])
```

### Model Inspection

```elixir
# Get model metadata
metadata = HMMTagger.metadata(model)
# => %{
#   trained_at: ~U[2026-01-06 ...],
#   training_size: 12543,
#   num_tags: 17,
#   vocab_size: 15632
# }

# Access probabilities (for debugging)
emission_prob = model.emission_probs["cat"][:noun]
transition_prob = model.transition_probs[{:det, :noun}][:verb]
```

### Cross-Validation

```elixir
# K-fold cross-validation
defmodule CrossValidation do
  def k_fold(corpus, k) do
    fold_size = div(length(corpus.sentences), k)
    
    1..k
    |> Enum.map(fn fold ->
      # Split data
      {train, test} = split_fold(corpus, fold, fold_size)
      
      # Train and evaluate
      training_data = Corpus.extract_pos_sequences(train)
      {:ok, model} = HMMTagger.train(HMMTagger.new(), training_data, [])
      
      test_data = Corpus.extract_pos_sequences(test)
      evaluate(model, test_data)
    end)
    |> average_metrics()
  end
end
```

## Performance Tips

### Training
- Use train/dev/test splits to avoid overfitting
- Experiment with smoothing_k values (0.0001 - 0.01)
- For large corpora, consider sampling for faster iteration

### Inference
- Load models once at application startup
- Cache models in ETS for multi-process access
- Use ensemble mode only when accuracy is critical

### Memory
- Trained models are compact (~5-10 MB for POS tagger)
- Models use Erlang term storage (efficient for BEAM)
- Consider model compression for very large vocabularies

## Comparison: Rule-Based vs Statistical

| Aspect | Rule-Based | HMM | Ensemble |
|--------|-----------|-----|----------|
| **Accuracy** | ~85% | ~95% | ~96% |
| **Speed** | Very fast | Fast | Medium |
| **Training** | None | Required | Required |
| **OOV Handling** | Heuristics | Statistical | Best of both |
| **Interpretability** | High | Low | Medium |
| **Memory** | <1 MB | ~5-10 MB | ~5-10 MB |

**Recommendations**:
- **Rule-based**: Quick prototyping, no training data, interpretability
- **HMM**: Production use, when accuracy matters, have training data
- **Ensemble**: Best accuracy, can afford slight performance cost

## Troubleshooting

### Low Accuracy

1. **Insufficient training data**: Need 10k+ sentences for good results
2. **Domain mismatch**: Train on data similar to your use case
3. **Smoothing too high**: Try reducing `smoothing_k`
4. **Evaluation on training data**: Always use held-out test set

### OOM Errors

1. **Large vocabulary**: Consider pruning rare words
2. **Trigram model**: Very large tag set increases memory quadratically
3. **Solution**: Use bigram transitions or reduce tag set granularity

### Slow Training

1. **Use sampling** for large corpora during development
2. **Profile** to find bottlenecks
3. **Consider parallel training** for cross-validation

## Contributing

To add a new statistical model:

1. Implement `Nasty.Statistics.Model` behaviour
2. Add training data loader if needed
3. Integrate with existing modules (e.g., `POSTagger`)
4. Add tests and benchmarks
5. Document in this file

## References

- [Universal Dependencies](https://universaldependencies.org/)
- [HMM POS Tagging](https://web.stanford.edu/~jurafsky/slp3/)
- [Viterbi Algorithm](https://en.wikipedia.org/wiki/Viterbi_algorithm)
- [Add-k Smoothing](https://en.wikipedia.org/wiki/Additive_smoothing)
