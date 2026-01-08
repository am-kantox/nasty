# Fine-tuning Transformers Guide

Complete guide to fine-tuning pre-trained transformer models on custom datasets in Nasty.

## Overview

Fine-tuning adapts a pre-trained transformer (BERT, RoBERTa, etc.) to your specific NLP task. Instead of training from scratch, you:

1. Start with a model trained on billions of tokens
2. Train for a few epochs on your task-specific data (1000+ examples)
3. Achieve state-of-the-art accuracy in minutes/hours instead of days/weeks

**Benefits:**
- 98-99% POS tagging accuracy (vs 97-98% BiLSTM-CRF)
- 93-95% NER F1 score (vs 75-80% rule-based)
- 10-100x less training data required
- Transfer learning from massive pre-training

## Quick Start

```bash
# Fine-tune RoBERTa for POS tagging
mix nasty.fine_tune.pos \
  --model roberta_base \
  --train data/en_ewt-ud-train.conllu \
  --validation data/en_ewt-ud-dev.conllu \
  --output models/pos_finetuned \
  --epochs 3 \
  --batch-size 16

# Fine-tune time: 10-30 minutes (CPU), 2-5 minutes (GPU)
# Result: 98-99% accuracy on UD English
```

## Prerequisites

### System Requirements

- **Memory**: 8GB+ RAM (16GB recommended)
- **Storage**: 2GB for models and data
- **GPU**: Optional but highly recommended (10-30x speedup with EXLA)
- **Time**: 10-30 minutes per run (CPU), 2-5 minutes (GPU)

### Required Data

Training data must be in **CoNLL-U format**:

```
1	The	the	DET	DT	_	2	det	_	_
2	cat	cat	NOUN	NN	_	3	nsubj	_	_
3	sat	sit	VERB	VBD	_	0	root	_	_

1	Dogs	dog	NOUN	NNS	_	2	nsubj	_	_
2	run	run	VERB	VBP	_	0	root	_	_
```

Download Universal Dependencies corpora:
- English: [UD_English-EWT](https://github.com/UniversalDependencies/UD_English-EWT)
- Spanish: [UD_Spanish-GSD](https://github.com/UniversalDependencies/UD_Spanish-GSD)
- More: [Universal Dependencies](https://universaldependencies.org/)

## POS Tagging Fine-tuning

### Basic Usage

```bash
mix nasty.fine_tune.pos \
  --model roberta_base \
  --train data/train.conllu \
  --epochs 3
```

### Full Configuration

```bash
mix nasty.fine_tune.pos \
  --model bert_base_cased \
  --train data/en_ewt-ud-train.conllu \
  --validation data/en_ewt-ud-dev.conllu \
  --output models/pos_bert_finetuned \
  --epochs 5 \
  --batch-size 32 \
  --learning-rate 0.00002 \
  --max-length 512 \
  --eval-steps 500
```

### Options Reference

| Option | Description | Default |
|--------|-------------|---------|
| `--model` | Base transformer (required) | - |
| `--train` | Training CoNLL-U file (required) | - |
| `--validation` | Validation file | None |
| `--output` | Output directory | priv/models/finetuned |
| `--epochs` | Training epochs | 3 |
| `--batch-size` | Batch size | 16 |
| `--learning-rate` | Learning rate | 3e-5 |
| `--max-length` | Max sequence length | 512 |
| `--eval-steps` | Evaluate every N steps | 500 |

## Supported Models

### English Models

**bert-base-cased** (110M params):
- Best for: Case-sensitive tasks, proper nouns
- Memory: ~500MB
- Speed: Medium

**roberta-base** (125M params):
- Best for: General purpose, highest accuracy
- Memory: ~550MB
- Speed: Medium
- **Recommended for most tasks**

**distilbert-base** (66M params):
- Best for: Fast inference, lower memory
- Memory: ~300MB
- Speed: Fast
- Accuracy: ~97% (vs 98% full BERT)

### Multilingual Models

**xlm-roberta-base** (270M params):
- Languages: 100 languages
- Best for: Spanish, Catalan, multilingual
- Memory: ~1.1GB
- Cross-lingual transfer: 90-95% of monolingual

**bert-base-multilingual-cased** (110M params):
- Languages: 104 languages
- Good baseline for many languages
- Memory: ~500MB

## Data Preparation

### Minimum Dataset Size

| Task | Minimum | Recommended | Optimal |
|------|---------|-------------|---------|
| POS Tagging | 1,000 sentences | 5,000 sentences | 10,000+ sentences |
| NER | 500 sentences | 2,000 sentences | 5,000+ sentences |
| Classification | 100 examples/class | 500 examples/class | 1,000+ examples/class |

### Data Splitting

Standard split ratios:

```
Total data: 12,000 sentences

Training:   9,600 (80%)
Validation: 1,200 (10%)
Test:       1,200 (10%)
```

### Data Quality Checklist

- [ ] Consistent annotation scheme (use Universal Dependencies)
- [ ] Balanced representation across domains (news, social media, technical)
- [ ] Clean text (no encoding errors, proper Unicode)
- [ ] No data leakage (train/val/test are disjoint)
- [ ] Representative of production data

## Hyperparameter Tuning

### Learning Rate

Most important hyperparameter!

```bash
# Too high: Model doesn't converge
--learning-rate 0.001  # DON'T USE

# Too low: Learning is very slow
--learning-rate 0.000001  # DON'T USE

# Good defaults:
--learning-rate 0.00003  # RoBERTa, BERT (3e-5)
--learning-rate 0.00002  # DistilBERT (2e-5)
--learning-rate 0.00005  # XLM-RoBERTa (5e-5)
```

### Batch Size

Balance between speed and memory:

```bash
# Small dataset or low memory
--batch-size 8

# Balanced (recommended)
--batch-size 16

# Large dataset, lots of memory
--batch-size 32

# Very large dataset, GPU
--batch-size 64
```

Memory usage by batch size:
- Batch 8: ~2GB GPU memory
- Batch 16: ~4GB GPU memory
- Batch 32: ~8GB GPU memory
- Batch 64: ~16GB GPU memory

### Number of Epochs

```bash
# Small dataset (1K-5K examples)
--epochs 5

# Medium dataset (5K-20K examples)
--epochs 3

# Large dataset (20K+ examples)
--epochs 2
```

Rule of thumb: Stop when validation loss plateaus (use validation set!)

### Max Sequence Length

```bash
# Short texts (tweets, titles)
--max-length 128  # Faster, uses less memory

# Normal texts (sentences, paragraphs)
--max-length 512  # Default, good balance

# Long texts (documents)
--max-length 1024  # Slower, uses more memory
```

## Programmatic Fine-tuning

For more control, use the API directly:

```elixir
alias Nasty.Statistics.Neural.Transformers.{Loader, FineTuner, DataPreprocessor}
alias Nasty.Statistics.Neural.DataLoader

# Load base model
{:ok, base_model} = Loader.load_model(:roberta_base)

# Load training data
{:ok, train_sentences} = DataLoader.load_conllu_file("data/train.conllu")

# Prepare examples
training_data = 
  Enum.map(train_sentences, fn sentence ->
    tokens = sentence.tokens
    labels = Enum.map(tokens, & &1.pos)
    {tokens, labels}
  end)

# Create label map (UPOS tags)
label_map = %{
  0 => "ADJ", 1 => "ADP", 2 => "ADV", 3 => "AUX",
  4 => "CCONJ", 5 => "DET", 6 => "INTJ", 7 => "NOUN",
  8 => "NUM", 9 => "PART", 10 => "PRON", 11 => "PROPN",
  12 => "PUNCT", 13 => "SCONJ", 14 => "SYM", 15 => "VERB", 16 => "X"
}

# Fine-tune
{:ok, finetuned} = FineTuner.fine_tune(
  base_model,
  training_data,
  :pos_tagging,
  num_labels: 17,
  label_map: label_map,
  epochs: 3,
  batch_size: 16,
  learning_rate: 3.0e-5
)

# Save
File.write!("models/pos_finetuned.axon", :erlang.term_to_binary(finetuned))
```

## Evaluation

### During Training

The CLI automatically evaluates on validation set:

```
Fine-tuning POS tagger
  Model: roberta_base
  Training data: data/train.conllu
  Output: models/pos_finetuned

Loading base model...
Model loaded: roberta_base

Loading training data...
Training examples: 8,724
Validation examples: 1,091
Number of POS tags: 17

Starting fine-tuning...

Epoch 1/3, Iteration 100: loss=0.3421, accuracy=0.891
Epoch 1/3, Iteration 200: loss=0.2156, accuracy=0.934
Epoch 1 completed. validation_loss: 0.1842, validation_accuracy: 0.951

Epoch 2/3, Iteration 100: loss=0.1523, accuracy=0.963
Epoch 2/3, Iteration 200: loss=0.1298, accuracy=0.971
Epoch 2 completed. validation_loss: 0.0921, validation_accuracy: 0.979

Epoch 3/3, Iteration 100: loss=0.0876, accuracy=0.981
Epoch 3/3, Iteration 200: loss=0.0745, accuracy=0.985
Epoch 3 completed. validation_loss: 0.0654, validation_accuracy: 0.987

Fine-tuning completed successfully!
Model saved to: models/pos_finetuned

Evaluating on validation set...

Validation Results:
  Accuracy: 98.72%
  Total predictions: 16,427
  Correct predictions: 16,217
```

### Post-training Evaluation

Test on held-out test set:

```bash
mix nasty.eval \
  --model models/pos_finetuned.axon \
  --test data/en_ewt-ud-test.conllu \
  --type pos_tagging
```

## Troubleshooting

### Out of Memory

**Symptoms**: Process crashes, CUDA out of memory

**Solutions**:
1. Reduce batch size: `--batch-size 8`
2. Reduce max length: `--max-length 256`
3. Use smaller model: `distilbert-base` instead of `roberta-base`
4. Use gradient accumulation (API only)

### Training Too Slow

**Symptoms**: Hours per epoch

**Solutions**:
1. Enable GPU: Set `XLA_TARGET=cuda` env var
2. Increase batch size: `--batch-size 32`
3. Reduce max length: `--max-length 256`
4. Use DistilBERT instead of BERT

### Poor Accuracy

**Symptoms**: Validation accuracy <95%

**Solutions**:
1. Train longer: `--epochs 5`
2. Increase dataset size (need 5K+ sentences)
3. Lower learning rate: `--learning-rate 0.00001`
4. Check data quality (annotation errors?)
5. Try different model: RoBERTa instead of BERT

### Overfitting

**Symptoms**: High training accuracy, low validation accuracy

**Solutions**:
1. More training data
2. Fewer epochs: `--epochs 2`
3. Higher learning rate: `--learning-rate 0.00005`
4. Use validation set for early stopping

### Model Not Learning

**Symptoms**: Loss stays constant

**Solutions**:
1. Higher learning rate: `--learning-rate 0.0001`
2. Check data format (is it loading correctly?)
3. Verify labels are correct
4. Try different optimizer (edit FineTuner code)

## Best Practices

### 1. Always Use Validation Set

```bash
# GOOD: Monitor validation performance
mix nasty.fine_tune.pos \
  --train data/train.conllu \
  --validation data/dev.conllu

# BAD: No way to detect overfitting
mix nasty.fine_tune.pos \
  --train data/train.conllu
```

### 2. Start with Defaults

Don't tune hyperparameters until you see the baseline:

```bash
# First run: Use defaults
mix nasty.fine_tune.pos --model roberta_base --train data/train.conllu

# Then: Tune if needed
```

### 3. Use RoBERTa for Best Accuracy

```bash
# Highest accuracy
--model roberta_base

# Not: BERT or DistilBERT (unless you need speed/size)
```

### 4. Save Intermediate Checkpoints

Models are saved automatically to output directory. Keep multiple versions:

```
models/
  pos_epoch1.axon
  pos_epoch2.axon
  pos_epoch3.axon
  pos_final.axon  # Best model
```

### 5. Document Your Configuration

Keep a log of what worked:

```
# models/pos_finetuned/README.md

Model: RoBERTa-base
Training data: UD_English-EWT (8,724 sentences)
Epochs: 3
Batch size: 16
Learning rate: 3e-5
Final accuracy: 98.7%
Training time: 15 minutes (GPU)
```

## Production Deployment

After fine-tuning, deploy to production:

### 1. Quantize for Efficiency

```bash
mix nasty.quantize \
  --model models/pos_finetuned.axon \
  --calibration data/calibration.conllu \
  --output models/pos_finetuned_int8.axon
```

Result: 4x smaller, 2-3x faster, <1% accuracy loss

### 2. Load in Production

```elixir
# Load quantized model
{:ok, model} = INT8.load("models/pos_finetuned_int8.axon")

# Use for inference
def tag_sentence(text) do
  {:ok, tokens} = Nasty.parse(text, language: :en)
  {:ok, tagged} = apply_model(model, tokens)
  tagged
end
```

### 3. Monitor Performance

Track key metrics:
- Accuracy on representative samples (weekly)
- Inference latency (should be <100ms per sentence)
- Memory usage (should be stable)
- Error rate by domain/source

## Advanced Topics

### Few-shot Learning

Fine-tune with minimal data (100-500 examples):

```elixir
FineTuner.few_shot_fine_tune(
  base_model,
  small_dataset,
  :pos_tagging,
  epochs: 10,
  learning_rate: 1.0e-5,
  data_augmentation: true
)
```

### Domain Adaptation

Fine-tune on domain-specific data:

```bash
# Medical text
mix nasty.fine_tune.pos \
  --model roberta_base \
  --train data/medical_train.conllu

# Legal text
mix nasty.fine_tune.pos \
  --model roberta_base \
  --train data/legal_train.conllu
```

### Multilingual Fine-tuning

Use XLM-RoBERTa for multiple languages:

```bash
mix nasty.fine_tune.pos \
  --model xlm_roberta_base \
  --train data/multilingual_train.conllu  # Mix of en, es, ca
```

## See Also

- [QUANTIZATION.md](QUANTIZATION.md) - Optimize fine-tuned models
- [ZERO_SHOT.md](ZERO_SHOT.md) - Classification without training
- [CROSS_LINGUAL.md](CROSS_LINGUAL.md) - Transfer across languages
- [NEURAL_MODELS.md](NEURAL_MODELS.md) - Neural architecture details
