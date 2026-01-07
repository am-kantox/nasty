# Neural Models in Nasty

Complete guide to using neural network models in Nasty for state-of-the-art NLP performance.

## Overview

Nasty integrates neural network models using **Axon**, Elixir's neural network library, providing:

- **BiLSTM-CRF architecture** for sequence tagging (POS, NER)
- **97-98% accuracy** on standard POS tagging benchmarks
- **EXLA JIT compilation** for 10-100x speedup
- **Seamless integration** with existing pipeline
- **Pre-trained embedding support** (GloVe, FastText)
- **Model persistence** and loading
- **Graceful fallbacks** to HMM and rule-based models

## Quick Start

### Installation

Neural dependencies are already included in `mix.exs`:

```elixir
# Already added
{:axon, "~> 0.7"},      # Neural networks
{:nx, "~> 0.9"},        # Numerical computing
{:exla, "~> 0.9"},      # XLA compiler (GPU/CPU acceleration)
{:bumblebee, "~> 0.6"}, # Pre-trained models
{:tokenizers, "~> 0.5"} # Fast tokenization
```

### Basic Usage

```elixir
# Parse text with neural POS tagger
{:ok, ast} = Nasty.parse("The cat sat on the mat.", 
  language: :en,
  model: :neural
)

# Tokens will have POS tags predicted by neural model
```

### Training Your Own Model

```bash
# Download Universal Dependencies corpus
# https://universaldependencies.org/

# Train neural POS tagger
mix nasty.train.neural_pos \
  --corpus data/en_ewt-ud-train.conllu \
  --test-corpus data/en_ewt-ud-test.conllu \
  --epochs 10 \
  --hidden-size 256

# Model saved to priv/models/en/pos_neural_v1.axon
```

### Using Trained Models

```elixir
alias Nasty.Statistics.POSTagging.NeuralTagger

# Load model
{:ok, model} = NeuralTagger.load("priv/models/en/pos_neural_v1.axon")

# Predict
words = ["The", "cat", "sat"]
{:ok, tags} = NeuralTagger.predict(model, words, [])
# => {:ok, [:det, :noun, :verb]}
```

## Architecture

### BiLSTM-CRF

The default architecture is **Bidirectional LSTM with CRF** (Conditional Random Field):

```
Input Words
    ↓
Word Embeddings (300d)
    ↓
BiLSTM Layer 1 (256 hidden units)
    ↓
Dropout (0.3)
    ↓
BiLSTM Layer 2 (256 hidden units)
    ↓
Dense Projection → POS Tags
    ↓
Softmax/CRF
    ↓
Output Tags
```

**Key Features:**
- Bidirectional context (forward + backward)
- Optional character-level CNN for OOV handling
- Dropout regularization
- 2-3 LSTM layers (configurable)
- 256-512 hidden units (configurable)

### Performance

**Accuracy:**
- POS Tagging: 97-98% (vs 95% HMM, 85% rule-based)
- NER: 88-92% F1 (future)
- Dependency Parsing: 94-96% UAS (future)

**Speed (on UD English, 12k sentences):**
- CPU: ~30-60 minutes training
- GPU (EXLA): ~5-10 minutes training
- Inference: ~1000-5000 tokens/second (CPU)
- Inference: ~10000+ tokens/second (GPU)

## Model Integration Modes

Nasty provides multiple integration modes:

### 1. Neural Only (`:neural`)

Uses only the neural model:

```elixir
{:ok, ast} = Nasty.parse(text, language: :en, model: :neural)
```

**Fallback:** If neural model unavailable, falls back to HMM → rule-based.

### 2. Neural Ensemble (`:neural_ensemble`)

Combines neural + HMM + rule-based:

```elixir
{:ok, ast} = Nasty.parse(text, language: :en, model: :neural_ensemble)
```

**Strategy:**
- Use rule-based for punctuation and numbers (high confidence)
- Use neural predictions for content words
- Best accuracy overall

### 3. Traditional Modes

Still available:
- `:rule_based` - Fast, 85% accuracy
- `:hmm` - 95% accuracy
- `:ensemble` - HMM + rules

## Training Guide

### 1. Prepare Data

Download Universal Dependencies corpus:

```bash
# English
wget https://raw.githubusercontent.com/UniversalDependencies/UD_English-EWT/master/en_ewt-ud-train.conllu

# Or other languages
# Spanish, Catalan, etc.
```

### 2. Train Model

```bash
mix nasty.train.neural_pos \
  --corpus en_ewt-ud-train.conllu \
  --test-corpus en_ewt-ud-test.conllu \
  --output priv/models/en/pos_neural_v1.axon \
  --epochs 10 \
  --batch-size 32 \
  --learning-rate 0.001 \
  --hidden-size 256 \
  --num-layers 2 \
  --dropout 0.3 \
  --use-char-cnn false
```

### 3. Evaluate

The training task automatically evaluates on test set and reports:
- Overall accuracy
- Per-tag precision, recall, F1
- Confusion matrix (if requested)

### 4. Deploy

Models are automatically saved with:
- Model weights (`.axon` file)
- Metadata (`.meta.json` file)
- Vocabulary and tag mappings

Load via `ModelLoader.load_latest(:en, :pos_tagging_neural)` or directly with `NeuralTagger.load/1`.

## Programmatic Training

```elixir
alias Nasty.Statistics.POSTagging.NeuralTagger
alias Nasty.Statistics.Neural.DataLoader

# Load corpus
{:ok, sentences} = DataLoader.load_conllu("train.conllu")

# Split data
{train, valid} = DataLoader.split(sentences, [0.9, 0.1])

# Build vocabularies
{:ok, vocab, tag_vocab} = DataLoader.build_vocabularies(train, min_freq: 2)

# Create model
tagger = NeuralTagger.new(
  vocab: vocab,
  tag_vocab: tag_vocab,
  embedding_dim: 300,
  hidden_size: 256,
  num_layers: 2,
  dropout: 0.3
)

# Train
{:ok, trained} = NeuralTagger.train(tagger, train,
  epochs: 10,
  batch_size: 32,
  learning_rate: 0.001,
  validation_split: 0.1
)

# Save
NeuralTagger.save(trained, "my_model.axon")
```

## Pre-trained Embeddings

### Using GloVe

```elixir
alias Nasty.Statistics.Neural.Embeddings

# Load GloVe embeddings
{:ok, embeddings} = Embeddings.load_glove("glove.6B.300d.txt", vocab)

# Use during training
tagger = NeuralTagger.new(
  vocab: vocab,
  tag_vocab: tag_vocab,
  pretrained_embeddings: embeddings
)
```

Download GloVe:
```bash
wget http://nlp.stanford.edu/data/glove.6B.zip
unzip glove.6B.zip
```

## Advanced Features

### Character-Level CNN

For better OOV handling:

```bash
mix nasty.train.neural_pos \
  --corpus train.conllu \
  --use-char-cnn \
  --char-filters 3,4,5 \
  --char-num-filters 30
```

### Custom Architectures

Extend `Nasty.Statistics.Neural.Architectures.BiLSTMCRF`:

```elixir
defmodule MyArchitecture do
  def build(opts) do
    # Custom Axon model
    Axon.input("tokens")
    |> Axon.embedding(opts[:vocab_size], opts[:embedding_dim])
    |> # ... your architecture
  end
end
```

### Streaming Training

For large datasets:

```elixir
DataLoader.stream_batches("huge_corpus.conllu", vocab, tag_vocab, batch_size: 64)
|> Stream.take(1000)  # Process in chunks
|> Enum.each(&train_batch/1)
```

## Troubleshooting

### EXLA Compilation Issues

If EXLA fails to compile:

```bash
# Install XLA dependencies
# Ubuntu/Debian:
sudo apt-get install build-essential

# Set compiler flags
export ELIXIR_ERL_OPTIONS="+fnu"
mix deps.clean exla --build
mix deps.get
```

### Out of Memory

Reduce batch size:

```bash
mix nasty.train.neural_pos --batch-size 16  # Instead of 32
```

Or use gradient accumulation:

```elixir
# In training opts
accumulation_steps: 4
```

### Slow Training

Enable EXLA:

```elixir
# Should be automatic, but verify:
compiler: EXLA
```

Use GPU if available:

```bash
export XLA_TARGET=cuda
```

## Future Enhancements

- **Transformers**: BERT, RoBERTa via Bumblebee
- **NER models**: BiLSTM-CRF for named entity recognition
- **Dependency parsing**: Biaffine attention parser
- **Multilingual**: mBERT, XLM-R support
- **Model quantization**: INT8 for faster inference
- **Knowledge distillation**: Compress large models

## See Also

- [TRAINING_NEURAL.md](TRAINING_NEURAL.md) - Detailed training guide
- [PRETRAINED_MODELS.md](PRETRAINED_MODELS.md) - Using transformers
- [API.md](API.md) - Full API documentation
- [BiLSTM-CRF paper](https://arxiv.org/abs/1508.01991)
- [Axon documentation](https://hexdocs.pm/axon)
