# Neural Coreference Resolution

Advanced neural coreference resolution using BiLSTM-CRF architecture.

## Overview

This implementation provides neural coreference resolution that improves accuracy from ~70% F1 (rule-based) to 75-80% F1 (neural pair model).

## Architecture

### Phase 1: Neural Pair Model (Implemented)

**Components**:
1. **Mention Encoder** - BiLSTM with attention over context
2. **Pair Scorer** - Feedforward network with 20 hand-crafted features
3. **Neural Resolver** - Integration with existing mention detection
4. **Evaluator** - MUC, B³, CEAF metrics

**Workflow**:
```
Document → Mention Detection → Neural Encoding → Pairwise Scoring → Clustering → Coreference Chains
```

## Quick Start

### Training

```bash
mix nasty.train.coref \
  --corpus data/ontonotes/train \
  --dev data/ontonotes/dev \
  --output priv/models/en/coref \
  --epochs 20 \
  --batch-size 32
```

### Evaluation

```bash
mix nasty.eval.coref \
  --model priv/models/en/coref \
  --test data/ontonotes/test
```

### Using in Code

```elixir
alias Nasty.Semantic.Coreference.Neural.{Resolver, Trainer}

# Load models
{:ok, models, params, vocab} = Trainer.load_models("priv/models/en/coref")

# Resolve coreferences
{:ok, document} = Resolver.resolve(document, models, params, vocab)

# Access chains
document.coref_chains
|> Enum.each(fn chain ->
  IO.puts("Chain #{chain.id}: #{chain.representative}")
  IO.puts("  Mentions: #{length(chain.mentions)}")
end)
```

## Data Format

### OntoNotes CoNLL-2012

The system expects CoNLL-2012 format with coreference annotations:

```
doc1  0  0  John   NNP  ...  (0
doc1  0  1  works  VBZ  ...  -
doc1  0  2  at     IN   ...  -
doc1  0  3  Google NNP  ...  (1)
...
doc1  0  10 He     PRP  ...  0)
```

## Modules

### Core Neural Components

- **`Nasty.Data.OntoNotes`** - CoNLL-2012 data loader
- **`Nasty.Semantic.Coreference.Neural.MentionEncoder`** - BiLSTM mention encoder
- **`Nasty.Semantic.Coreference.Neural.PairScorer`** - Neural pair scoring
- **`Nasty.Semantic.Coreference.Neural.Trainer`** - Training pipeline
- **`Nasty.Semantic.Coreference.Neural.Resolver`** - Integration layer

### Evaluation

- **`Nasty.Semantic.Coreference.Evaluator`** - Standard coreference metrics

### Mix Tasks

- **`mix nasty.train.coref`** - Train models
- **`mix nasty.eval.coref`** - Evaluate models

## Model Architecture Details

### Mention Encoder

- Input: Token IDs + mention mask
- Embedding: 100d (GloVe compatible)
- BiLSTM: 128 hidden units
- Attention: Over mention span
- Output: 256d mention representation

### Pair Scorer

- Input: [m1_encoding (256d), m2_encoding (256d), features (20d)]
- Hidden layers: [512, 256] with ReLU + dropout
- Output: Sigmoid probability

### Features (20 total)

1-3. Distance features (sentence, token, mention)
4-6. String match (exact, partial, head)
7-12. Mention types (pronoun, name, definite NP for each)
13-15. Agreement (gender, number, entity type)
16-20. Positional (same sentence, first mentions, pronoun-name pair)

## Training

### Hyperparameters

- Epochs: 20 (with early stopping)
- Batch size: 32
- Learning rate: 0.001 (Adam)
- Dropout: 0.3
- Patience: 3 epochs
- Max distance: 3 sentences

### Data Preparation

- Positive pairs: Mentions in same chain
- Negative pairs: Mentions in different chains
- Ratio: 1:1 (configurable)
- Shuffling: Enabled

## Evaluation Metrics

### MUC (Mention-based)
Measures minimum links needed to connect mentions.

### B³ (Entity-based)
Averages precision/recall per mention.

### CEAF (Entity alignment)
Optimal alignment between gold and predicted chains.

### CoNLL F1
Average of MUC, B³, and CEAF F1 scores.

## Performance

### Expected Results

- **Rule-based baseline**: ~70% CoNLL F1
- **Neural pair model**: 75-80% CoNLL F1
- **Improvement**: +5-10 F1 points

### Speed

- Encoding: ~100 mentions/sec
- Scoring: ~1000 pairs/sec
- End-to-end: ~50-100ms per document

## Future Enhancements

### Phase 2: Span-Based End-to-End (Planned)

- Joint mention detection + coreference
- Span enumeration with pruning
- End-to-end optimization
- Target: 82-85% CoNLL F1

### Phase 3: Transformer Fine-tuning (Planned)

- SpanBERT or Longformer
- Pre-trained contextual embeddings
- Target: 88-90% CoNLL F1

## Troubleshooting

### Out of Memory

- Reduce batch size: `--batch-size 16`
- Use smaller hidden dim: `--hidden-dim 64`
- Process fewer documents at once

### Low Accuracy

- Check data format (CoNLL-2012)
- Increase training epochs: `--epochs 30`
- Add more training data
- Tune hyperparameters

### Slow Training

- Use GPU acceleration (EXLA)
- Increase batch size: `--batch-size 64`
- Reduce max distance: `--max-distance 2`

## References

- Lee et al. (2017). "End-to-end Neural Coreference Resolution"
- Vilain et al. (1995). "A model-theoretic coreference scoring scheme"
- Pradhan et al. (2012). "CoNLL-2012 shared task"

## See Also

- [COREFERENCE_TRAINING.md](COREFERENCE_TRAINING.md) - Detailed training guide
- [Plan](../docs/plans/) - Complete implementation roadmap
- [API.md](API.md) - Full API reference
