# Training Neural Models Guide

This guide provides detailed instructions for training neural models in Nasty, from data preparation to deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Data Preparation](#data-preparation)
3. [Training POS Tagging Models](#training-pos-tagging-models)
4. [Advanced Training Options](#advanced-training-options)
5. [Model Evaluation](#model-evaluation)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **Memory**: Minimum 4GB RAM for training, 8GB+ recommended
- **CPU**: Multi-core CPU (4+ cores recommended)
- **GPU**: Optional but highly recommended (10-100x speedup with EXLA)
- **Storage**: 500MB-2GB for models and training data

### Dependencies

All neural dependencies are included in `mix.exs`:

```elixir
{:axon, "~> 0.7"},
{:nx, "~> 0.9"},
{:exla, "~> 0.9"},
{:bumblebee, "~> 0.6"}
```

Install with:

```bash
mix deps.get
```

### Enable GPU Acceleration (Optional)

Set environment variable for EXLA to use GPU:

```bash
export XLA_TARGET=cuda120  # or cuda118, rocm, etc.
mix deps.compile
```

## Data Preparation

### CoNLL-U Format

Neural models train on CoNLL-U formatted data. Each sentence is separated by blank lines, with one token per line:

```
1	The	the	DET	DT	_	2	det	_	_
2	cat	cat	NOUN	NN	_	3	subj	_	_
3	sat	sit	VERB	VBD	_	0	root	_	_

1	Dogs	dog	NOUN	NNS	_	2	subj	_	_
2	run	run	VERB	VBP	_	0	root	_	_
```

Columns (tab-separated):
1. Index
2. Word form
3. Lemma
4. **UPOS tag** (used for training)
5. XPOS tag
6. Features
7. Head
8. Dependency relation
9-10. Additional annotations

### Where to Get Training Data

**Universal Dependencies** corpora:
- English: [UD_English-EWT](https://github.com/UniversalDependencies/UD_English-EWT)
- Spanish: [UD_Spanish-GSD](https://github.com/UniversalDependencies/UD_Spanish-GSD)
- Catalan: [UD_Catalan-AnCora](https://github.com/UniversalDependencies/UD_Catalan-AnCora)

Download and extract:

```bash
cd data
git clone https://github.com/UniversalDependencies/UD_English-EWT
```

### Data Split Recommendations

- **Training**: 80% (or use provided train split)
- **Validation**: 10% (or use provided dev split)
- **Test**: 10% (or use provided test split)

The training pipeline handles splitting automatically if you provide a single file.

## Training POS Tagging Models

### Quick Start - CLI Training

The easiest way to train is using the Mix task:

```bash
mix nasty.train.neural_pos \
  --corpus data/UD_English-EWT/en_ewt-ud-train.conllu \
  --output models/pos_neural_v1.axon \
  --epochs 10 \
  --batch-size 32
```

### CLI Options Reference

```bash
mix nasty.train.neural_pos [options]

Required:
  --corpus PATH          Path to CoNLL-U training corpus

Optional:
  --output PATH          Model save path (default: pos_neural.axon)
  --validation PATH      Path to validation corpus (auto-split if not provided)
  --epochs N             Number of training epochs (default: 10)
  --batch-size N         Batch size (default: 32)
  --learning-rate F      Learning rate (default: 0.001)
  --hidden-size N        LSTM hidden size (default: 256)
  --embedding-dim N      Word embedding dimension (default: 300)
  --num-layers N         Number of LSTM layers (default: 2)
  --dropout F            Dropout rate (default: 0.3)
  --use-char-cnn         Enable character CNN (default: enabled)
  --char-embedding-dim N Character embedding dim (default: 50)
  --optimizer NAME       Optimizer: adam, sgd, adamw (default: adam)
  --early-stopping N     Early stopping patience (default: 3)
  --checkpoint-dir PATH  Save checkpoints during training
  --min-freq N           Min word frequency for vocab (default: 1)
  --validation-split F   Validation split fraction (default: 0.1)
```

### Programmatic Training

For more control, train programmatically:

```elixir
alias Nasty.Statistics.POSTagging.NeuralTagger
alias Nasty.Statistics.Neural.DataLoader

# Load training data
{:ok, sentences} = DataLoader.load_conllu_file("data/train.conllu")

# Split into train/validation
{train_data, valid_data} = DataLoader.split_data(sentences, validation_split: 0.1)

# Create and configure tagger
tagger = NeuralTagger.new(training_data: train_data)

# Train with custom options
{:ok, trained_tagger} = NeuralTagger.train(tagger, train_data,
  epochs: 20,
  batch_size: 32,
  learning_rate: 0.001,
  hidden_size: 512,
  embedding_dim: 300,
  num_lstm_layers: 3,
  dropout: 0.5,
  use_char_cnn: true,
  validation_data: valid_data,
  early_stopping_patience: 5
)

# Save trained model
:ok = NeuralTagger.save(trained_tagger, "models/pos_advanced.axon")
```

## Advanced Training Options

### Hyperparameter Tuning

**Hidden Size** (`--hidden-size`):
- Small (128-256): Faster training, less memory, slightly lower accuracy
- Medium (256-512): Balanced performance (default: 256)
- Large (512-1024): Best accuracy, requires more memory/time

**Embedding Dimension** (`--embedding-dim`):
- Small (50-100): Fast, low memory
- Medium (300): Good balance (default, matches GloVe)
- Large (300-1024): For very large corpora

**Number of LSTM Layers** (`--num-layers`):
- 1 layer: Fast, simple patterns
- 2 layers: Balanced (default, recommended)
- 3+ layers: Complex patterns, risk overfitting

**Dropout** (`--dropout`):
- 0.0: No regularization (risk overfitting)
- 0.3: Good default
- 0.5: Strong regularization for small datasets

**Batch Size** (`--batch-size`):
- Small (8-16): Better generalization, slower
- Medium (32): Good balance (default)
- Large (64-128): Faster training, needs more memory

### Character CNN Configuration

Character-level CNN helps with out-of-vocabulary words:

```bash
mix nasty.train.neural_pos \
  --corpus data/train.conllu \
  --use-char-cnn \
  --char-embedding-dim 50 \
  --char-vocab-size 150
```

Disable if training is too slow:

```bash
mix nasty.train.neural_pos \
  --corpus data/train.conllu \
  --no-char-cnn
```

### Using Pre-trained Embeddings

Load GloVe embeddings for better initialization:

```elixir
alias Nasty.Statistics.Neural.Embeddings

# Load GloVe vectors
glove_embeddings = Embeddings.load_glove("data/glove.6B.300d.txt", word_vocab)

# Train with pre-trained embeddings
{:ok, tagger} = NeuralTagger.train(base_tagger, train_data,
  pretrained_embeddings: glove_embeddings,
  freeze_embeddings: false  # Allow fine-tuning
)
```

Note: GloVe loading is currently a placeholder. Full implementation coming soon.

### Optimizer Selection

**Adam** (default):
- Adaptive learning rates
- Works well out-of-the-box
- Good for most use cases

**SGD**:
- Simple, stable
- May need learning rate scheduling
- Good baseline

**AdamW**:
- Adam with weight decay
- Better generalization
- Recommended for large models

```bash
mix nasty.train.neural_pos \
  --corpus data/train.conllu \
  --optimizer adamw \
  --learning-rate 0.0001
```

### Early Stopping

Automatically stop training when validation performance plateaus:

```bash
mix nasty.train.neural_pos \
  --corpus data/train.conllu \
  --validation data/dev.conllu \
  --early-stopping 5  # Stop after 5 epochs without improvement
```

### Checkpointing

Save model checkpoints during training:

```bash
mix nasty.train.neural_pos \
  --corpus data/train.conllu \
  --checkpoint-dir checkpoints/ \
  --checkpoint-frequency 2  # Save every 2 epochs
```

Checkpoints are named: `checkpoint_epoch_001.axon`, `checkpoint_epoch_002.axon`, etc.

## Model Evaluation

### During Training

The training task prints per-tag metrics:

```
Epoch 1/10
  Loss: 0.456
  Accuracy: 0.923
  
Per-tag accuracy:
  NOUN: 0.957
  VERB: 0.942
  DET: 0.989
  ...
```

### Post-Training Evaluation

Evaluate on test set:

```bash
mix nasty.eval.neural_pos \
  --model models/pos_neural_v1.axon \
  --test data/en_ewt-ud-test.conllu
```

Or programmatically:

```elixir
{:ok, model} = NeuralTagger.load("models/pos_neural_v1.axon")
{:ok, test_sentences} = DataLoader.load_conllu_file("data/test.conllu")

# Evaluate
correct = 0
total = 0

for {words, gold_tags} <- test_sentences do
  {:ok, pred_tags} = NeuralTagger.predict(model, words, [])
  
  correct = correct + Enum.count(Enum.zip(pred_tags, gold_tags), fn {p, g} -> p == g end)
  total = total + length(gold_tags)
end

accuracy = correct / total
IO.puts("Accuracy: #{Float.round(accuracy * 100, 2)}%")
```

### Metrics to Track

- **Overall Accuracy**: Percentage of correctly tagged tokens
- **Per-Tag Accuracy**: Accuracy for each POS tag
- **Per-Tag Precision/Recall**: For detailed error analysis
- **OOV Accuracy**: Performance on out-of-vocabulary words
- **Training Time**: Total time and time per epoch
- **Convergence**: Number of epochs to best validation score

## Troubleshooting

### Out of Memory

**Symptoms**: Process crashes with memory error

**Solutions**:
1. Reduce batch size: `--batch-size 16` or `--batch-size 8`
2. Reduce hidden size: `--hidden-size 128`
3. Reduce embedding dimension: `--embedding-dim 100`
4. Disable character CNN: `--no-char-cnn`
5. Use smaller training corpus subset

### Training Too Slow

**Symptoms**: Hours per epoch

**Solutions**:
1. Enable EXLA GPU support (see Prerequisites)
2. Increase batch size: `--batch-size 64`
3. Disable character CNN if not needed
4. Use fewer LSTM layers: `--num-layers 1`
5. Reduce hidden size: `--hidden-size 128`

### Overfitting

**Symptoms**: High training accuracy, low validation accuracy

**Solutions**:
1. Increase dropout: `--dropout 0.5`
2. Use more training data
3. Enable early stopping: `--early-stopping 3`
4. Reduce model complexity (fewer layers, smaller hidden size)
5. Add L2 regularization

### Underfitting

**Symptoms**: Low training and validation accuracy

**Solutions**:
1. Increase model capacity: `--hidden-size 512 --num-layers 3`
2. Train longer: `--epochs 20`
3. Lower dropout: `--dropout 0.2`
4. Increase learning rate: `--learning-rate 0.01`
5. Check data quality (wrong labels, formatting issues)

### Validation Loss Not Decreasing

**Symptoms**: Validation loss stays flat or increases

**Solutions**:
1. Lower learning rate: `--learning-rate 0.0001`
2. Add early stopping
3. Check for data issues (train/validation overlap, different distributions)
4. Try different optimizer: `--optimizer adamw`

### CoNLL-U Loading Errors

**Symptoms**: Parser errors, wrong tag counts

**Solutions**:
1. Verify file format (tab-separated, 10 columns)
2. Check for empty lines between sentences
3. Ensure UTF-8 encoding
4. Remove or fix malformed lines
5. Validate with UD validator: https://universaldependencies.org/tools.html

### Model Not Learning

**Symptoms**: Loss stays constant, accuracy at baseline

**Solutions**:
1. Check data quality (are labels correct?)
2. Verify vocabulary is being built correctly
3. Increase learning rate: `--learning-rate 0.01`
4. Remove or reduce dropout initially
5. Check for bugs in data preprocessing

## Best Practices

### For Small Datasets (<5K sentences)

```bash
mix nasty.train.neural_pos \
  --corpus data/small_corpus.conllu \
  --epochs 20 \
  --batch-size 16 \
  --hidden-size 128 \
  --embedding-dim 100 \
  --dropout 0.5 \
  --early-stopping 5 \
  --no-char-cnn
```

### For Medium Datasets (5K-50K sentences)

```bash
mix nasty.train.neural_pos \
  --corpus data/medium_corpus.conllu \
  --epochs 15 \
  --batch-size 32 \
  --hidden-size 256 \
  --embedding-dim 300 \
  --dropout 0.3 \
  --use-char-cnn \
  --early-stopping 3
```

### For Large Datasets (50K+ sentences)

```bash
mix nasty.train.neural_pos \
  --corpus data/large_corpus.conllu \
  --epochs 10 \
  --batch-size 64 \
  --hidden-size 512 \
  --embedding-dim 300 \
  --num-layers 3 \
  --dropout 0.3 \
  --use-char-cnn \
  --optimizer adamw \
  --learning-rate 0.0001
```

## Production Deployment

After training, deploy your model:

1. **Save the trained model**:
   ```bash
   # Model is already saved by training task
   ls -lh models/pos_neural_v1.axon
   ```

2. **Load in production**:
   ```elixir
   {:ok, model} = NeuralTagger.load("models/pos_neural_v1.axon")
   ```

3. **Integrate with POSTagger**:
   ```elixir
   # Use neural mode
   {:ok, ast} = Nasty.parse(text, language: :en, model: :neural, neural_model: model)
   
   # Or use ensemble mode
   {:ok, ast} = Nasty.parse(text, language: :en, model: :neural_ensemble, neural_model: model)
   ```

4. **Monitor performance**:
   - Track accuracy on representative sample
   - Monitor latency (should be <100ms per sentence on CPU)
   - Watch memory usage

## Next Steps

- Read [NEURAL_MODELS.md](NEURAL_MODELS.md) for architecture details
- See [PRETRAINED_MODELS.md](PRETRAINED_MODELS.md) for using Bumblebee transformers
- Check [examples/](../examples/) for complete training scripts
- Explore UD treebanks for more training data
