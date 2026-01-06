# Training Guide: Custom Statistical Models

This guide walks you through training your own statistical models for Nasty.

## Prerequisites

- Elixir 1.19+ installed
- Nasty project cloned and dependencies installed (`mix deps.get`)
- Basic familiarity with NLP concepts (POS tagging, parsing, etc.)

## Quick Start: Train an HMM POS Tagger

### Step 1: Get Training Data

The easiest way to get started is with Universal Dependencies (UD) treebanks.

**Option A: Download English-EWT (recommended)**

```bash
# Create data directory
mkdir -p data

# Download from GitHub (replace VERSION with latest, e.g., r2.13)
cd data
wget https://github.com/UniversalDependencies/UD_English-EWT/archive/refs/tags/rVERSION.tar.gz
tar -xzf rVERSION.tar.gz
cd ..

# Files you need:
# - data/UD_English-EWT-rVERSION/en_ewt-ud-train.conllu  (~12.5k sentences)
# - data/UD_English-EWT-rVERSION/en_ewt-ud-dev.conllu    (~2k sentences)
# - data/UD_English-EWT-rVERSION/en_ewt-ud-test.conllu   (~2k sentences)
```

**Option B: Browse available treebanks**

Visit [universaldependencies.org](https://universaldependencies.org/) to explore treebanks for different languages and domains.

### Step 2: Train the Model

Use the provided training script:

```bash
./scripts/train_pos_tagger.exs \
  --corpus data/UD_English-EWT-r2.13/en_ewt-ud-train.conllu \
  --dev data/UD_English-EWT-r2.13/en_ewt-ud-dev.conllu \
  --test data/UD_English-EWT-r2.13/en_ewt-ud-test.conllu \
  --output priv/models/en/pos_hmm_ewt.model
```

This will:
1. Load and analyze the training data
2. Train an HMM model (takes ~30 seconds on typical hardware)
3. Evaluate on train, dev, and test sets
4. Save the trained model

**Expected output:**
```
=== Nasty HMM POS Tagger Training ===

Loading training corpus: data/.../en_ewt-ud-train.conllu
  Sentences: 12543
  Tokens: 204585
  Vocabulary: 15632
  POS tags: 17

Training HMM model (smoothing_k=0.001)...
  Training completed in 28547ms

Model Statistics:
  POS tags: 17
  Vocabulary: 15632
  Training size: 12543

--- Training Set Evaluation ---
  Accuracy: 98.45%
  Macro F1: 0.9621
  ...

--- Test Set Evaluation ---
  Accuracy: 94.73%
  Macro F1: 0.9247
  ...

✓ Training complete!
```

### Step 3: Use Your Model

```elixir
# Load the model
{:ok, model} = Nasty.Statistics.POSTagging.HMMTagger.load("priv/models/en/pos_hmm_ewt.model")

# Use it for parsing
{:ok, ast} = Nasty.parse("The cat sat on the mat.", 
  language: :en, 
  model: :hmm, 
  hmm_model: model
)

# Or use ensemble mode (combines HMM + rule-based)
{:ok, ast} = Nasty.parse("The cat sat on the mat.", 
  language: :en, 
  model: :ensemble, 
  hmm_model: model
)
```

## Advanced Training

### Hyperparameter Tuning

The most important hyperparameter is `smoothing_k`, which controls add-k smoothing:

```bash
# Try different smoothing values
for k in 0.0001 0.001 0.01 0.1; do
  ./scripts/train_pos_tagger.exs \
    --corpus data/.../train.conllu \
    --dev data/.../dev.conllu \
    --smoothing $k \
    --output models/hmm_k${k}.model
done

# Compare dev set performance and pick the best
```

**Smoothing guidelines:**
- **Lower values (0.0001-0.001)**: Better for in-vocabulary words, sharper distributions
- **Higher values (0.01-0.1)**: Better for out-of-vocabulary words, smoother distributions
- **Default (0.001)**: Good general-purpose value

### Training on Custom Data

If you have your own annotated data:

**1. Convert to CoNLL-U format**

CoNLL-U is a tab-separated format with 10 columns per token:

```
# sent_id = 1
# text = The cat sat.
1    The     the    DET   DT   _   2   det    _   _
2    cat     cat    NOUN  NN   _   3   nsubj  _   _
3    sat     sit    VERB  VBD  _   0   root   _   SpaceAfter=No
4    .       .      PUNCT .    _   3   punct  _   _
```

See [universaldependencies.org/format.html](https://universaldependencies.org/format.html) for full specification.

**2. Important fields for POS tagging:**
- Column 2 (FORM): The word
- Column 4 (UPOS): Universal POS tag
- Blank line separates sentences

**3. Minimal example:**

If you only have words and POS tags, you can create a minimal CoNLL-U file:

```elixir
# Create from your data
data = [
  {["The", "cat", "sat"], [:det, :noun, :verb]},
  {["A", "dog", "ran"], [:det, :noun, :verb]}
]

File.write!("my_data.conllu", Enum.map_join(data, "\n\n", fn {words, tags} ->
  Enum.zip(words, tags)
  |> Enum.with_index(1)
  |> Enum.map_join("\n", fn {{word, tag}, id} ->
    "#{id}\t#{word}\t#{String.downcase(word)}\t#{String.upcase(to_string(tag))}\t_\t_\t_\t_\t_\t_"
  end)
end))
```

### Domain-Specific Training

For specialized domains (medical, legal, technical), fine-tune on domain data:

**1. Start with a general model**
```bash
./scripts/train_pos_tagger.exs \
  --corpus data/general_corpus.conllu \
  --output models/general_pos.model
```

**2. Create domain-specific data**

Annotate ~1000-5000 sentences from your domain.

**3. Train on combined data**

```bash
# Concatenate general + domain data
cat data/general_corpus.conllu data/medical_corpus.conllu > data/combined.conllu

./scripts/train_pos_tagger.exs \
  --corpus data/combined.conllu \
  --test data/medical_test.conllu \
  --output models/medical_pos.model
```

## Evaluating Models

### Metrics Explained

**Accuracy**: Percentage of correctly tagged tokens
- Target: >94% for general English
- >90% is good for specialized domains

**F1 Score**: Harmonic mean of precision and recall
- Balanced measure of performance
- Per-tag F1 shows which tags are problematic

**Confusion Matrix**: Shows which tags get confused
- Useful for diagnosing problems
- Available via `Evaluator.print_confusion_matrix/1`

### Compare to Baseline

Always compare your statistical model to the rule-based baseline:

```elixir
# Rule-based
{:ok, tokens} = Nasty.Language.English.Tokenizer.tokenize(text)
{:ok, rule_tokens} = Nasty.Language.English.POSTagger.tag_pos(tokens, model: :rule_based)

# Statistical
{:ok, stat_tokens} = Nasty.Language.English.POSTagger.tag_pos(tokens, model: :hmm, hmm_model: model)

# Compare tags
Enum.zip(rule_tokens, stat_tokens)
|> Enum.each(fn {r, s} ->
  if r.pos_tag != s.pos_tag do
    IO.puts("#{r.text}: rule=#{r.pos_tag} vs hmm=#{s.pos_tag}")
  end
end)
```

### Error Analysis

Identify common errors:

```elixir
alias Nasty.Statistics.Evaluator

# Get confusion matrix
metrics = Evaluator.classification_metrics(gold_tags, pred_tags)
Evaluator.print_confusion_matrix(metrics.confusion_matrix)

# Find worst-performing tags
metrics.per_class
|> Enum.sort_by(fn {_tag, m} -> m.f1 end)
|> Enum.take(5)
|> Enum.each(fn {tag, m} ->
  IO.puts("#{tag}: F1=#{m.f1}, Support=#{m.support}")
end)
```

## Best Practices

### Data Quality

✅ **Do:**
- Use at least 10k sentences for training
- Validate annotation consistency
- Include diverse sentence structures
- Balance training data across domains

❌ **Don't:**
- Mix inconsistent annotation schemes
- Use data with many annotation errors
- Overtrain on homogeneous data
- Ignore class imbalance

### Model Selection

**Use rule-based when:**
- No training data available
- Need 100% reproducibility
- Require interpretability
- Speed is critical (<1ms per sentence)

**Use HMM when:**
- Have training data (10k+ sentences)
- Accuracy is more important than speed
- Domain-specific vocabulary
- Need to handle ambiguous cases

**Use ensemble when:**
- Want best overall accuracy
- Can afford slightly slower processing
- Have trained model available

### Production Deployment

**1. Model versioning**

Include version info in filename:
```
priv/models/en/pos_hmm_ewt_v1.0_20260106.model
```

**2. Model validation**

Test on holdout data before deploying:
```bash
./scripts/train_pos_tagger.exs \
  --test data/holdout_test.conllu \
  # ... load existing model and only evaluate
```

**3. Monitoring**

Track accuracy on production data:
```elixir
# Log predictions for sample review
{:ok, pred_tags} = HMMTagger.predict(model, words, [])
Logger.debug("POS prediction: #{inspect(Enum.zip(words, pred_tags))}")
```

**4. Model updates**

Retrain periodically with new data:
- Monthly: For rapidly evolving domains
- Quarterly: For general purpose
- Annually: For stable domains

## Troubleshooting

### Low Accuracy (<85%)

**Possible causes:**
1. **Insufficient training data** → Get more sentences
2. **Domain mismatch** → Train on domain-specific data
3. **Annotation errors** → Validate and clean data
4. **Wrong hyperparameters** → Tune smoothing_k on dev set

### High Training Accuracy but Low Test Accuracy

**Overfitting:**
- Add more training data
- Increase smoothing (try 0.01 or 0.1)
- Ensure train/test are from same distribution

### Model Too Large

**Reduce model size:**
- Prune rare words (vocabulary cutoff)
- Use bigram instead of trigram transitions
- Quantize probability tables

### Slow Training

**Speed up:**
- Use smaller dataset for development
- Profile with `mix profile.fprof`
- Consider parallel training (future enhancement)

## Next Steps

### Pre-trained Models

Once you've trained a high-quality model, consider:
- Sharing on GitHub releases
- Contributing to Nasty project
- Publishing as separate package

### Other Model Types

The same infrastructure supports:
- **PCFG parsers** (future)
- **CRF for NER** (future)
- **MaxEnt taggers** (alternative to HMM)

### Further Reading

- [Universal Dependencies](https://universaldependencies.org/)
- [HMM POS Tagging](https://web.stanford.edu/~jurafsky/slp3/)
- [CoNLL-U Format](https://universaldependencies.org/format.html)
- See `STATISTICAL_MODELS.md` for implementation details
