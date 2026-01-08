# Model Quantization Guide

Complete guide to quantizing neural models in Nasty for deployment optimization.

## Overview

Model quantization reduces model size and inference time by converting Float32 weights to lower-precision representations (INT8, INT4). This enables:

- **4x smaller models** (400MB → 100MB)
- **2-3x faster inference** on CPU
- **40-60% lower memory usage**
- **Minimal accuracy loss** (<1% with proper calibration)
- **Mobile and edge deployment** with reduced resource requirements

## Quantization Methods

Nasty supports three quantization approaches:

### 1. INT8 Post-Training Quantization (Recommended)

Convert trained Float32 models to INT8 after training.

**Advantages:**
- No retraining required
- Fast conversion (minutes)
- <1% accuracy degradation
- Works with any trained model

**Use when:**
- You have a trained model ready for deployment
- You need quick optimization
- Accuracy requirements are not extremely strict (>97%)

```elixir
alias Nasty.Statistics.Neural.Quantization.INT8

# Load trained model
{:ok, model} = NeuralTagger.load("models/pos_tagger.axon")

# Prepare calibration data (100-1000 representative samples)
calibration_data = load_calibration_samples("data/calibration.conllu", limit: 500)

# Quantize
{:ok, quantized} = INT8.quantize(model,
  calibration_data: calibration_data,
  calibration_method: :percentile,  # More robust than :minmax
  target_accuracy_loss: 0.01  # Max 1% loss
)

# Save
INT8.save(quantized, "models/pos_tagger_int8.axon")
```

### 2. Dynamic Quantization

Quantize weights at load time, keep activations in Float32.

**Advantages:**
- No calibration data needed
- Faster than static quantization
- Easy to apply

**Disadvantages:**
- Slower inference than INT8 (activations still Float32)
- 50% smaller (not 75% like INT8)

**Use when:**
- You don't have calibration data
- You need quick wins without accuracy concerns
- Memory is more constrained than compute

```elixir
alias Nasty.Statistics.Neural.Quantization.Dynamic

{:ok, model} = NeuralTagger.load("models/pos_tagger.axon")

# Quantize dynamically
{:ok, quantized} = Dynamic.quantize(model)

# Use immediately - no saving needed
{:ok, predictions} = Dynamic.predict(quantized, tokens)
```

### 3. Quantization-Aware Training (QAT)

Train model with quantization simulation from the start.

**Advantages:**
- Best accuracy (no degradation)
- Handles quantization errors during training
- Optimal for production

**Disadvantages:**
- Requires retraining
- Longer training time (1.5-2x)
- More complex setup

**Use when:**
- Accuracy is critical (medical, legal, finance)
- You're training from scratch anyway
- You have time for proper training

```elixir
alias Nasty.Statistics.Neural.Quantization.QAT
alias Nasty.Statistics.Neural.Transformers.FineTuner

# Fine-tune with QAT enabled
{:ok, model} = FineTuner.fine_tune(
  base_model,
  training_data,
  :pos_tagging,
  epochs: 5,
  quantization_aware: true,  # Enable QAT
  qat_opts: [
    bits: 8,
    fake_quantize: true
  ]
)

# Model is already quantization-ready
QAT.save(model, "models/pos_tagger_qat_int8.axon")
```

## Calibration Data

Calibration determines optimal quantization ranges for activations.

### Requirements

- **Size**: 100-1000 samples (more is better, diminishing returns after 1000)
- **Representativeness**: Must cover typical input distributions
- **Format**: Same as training data (tokens, sentences, etc.)

### Preparing Calibration Data

```elixir
# From CoNLL-U file
defmodule CalibrationLoader do
  def load_samples(path, opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)
    
    path
    |> DataLoader.load_conllu_file()
    |> elem(1)
    |> Enum.take(limit)
    |> Enum.map(fn sentence ->
      # Convert to format expected by model
      %{
        input_ids: sentence.input_ids,
        attention_mask: sentence.attention_mask
      }
    end)
  end
end

calibration_data = CalibrationLoader.load_samples("data/dev.conllu", limit: 500)
```

### Calibration Methods

**MinMax** (`:minmax`):
- Uses absolute min/max of activations
- Fast but sensitive to outliers
- Default method

```elixir
INT8.quantize(model, calibration_data: data, calibration_method: :minmax)
```

**Percentile** (`:percentile`):
- Uses 99.99th percentile instead of absolute max
- More robust to outliers
- Recommended for production

```elixir
INT8.quantize(model, 
  calibration_data: data,
  calibration_method: :percentile,
  percentile: 99.99
)
```

**Entropy** (`:entropy`):
- Minimizes KL divergence between FP32 and INT8
- Best accuracy but slowest
- Use for critical applications

```elixir
INT8.quantize(model,
  calibration_data: data,
  calibration_method: :entropy
)
```

## Model Comparison

### Before Quantization

```bash
# Original Float32 model
ls -lh models/pos_tagger.axon
# => 412M

# Inference time (CPU)
mix nasty.benchmark --model pos_tagger.axon
# => 45ms per sentence
```

### After INT8 Quantization

```bash
# Quantized INT8 model
ls -lh models/pos_tagger_int8.axon
# => 108M (3.8x smaller)

# Inference time (CPU)
mix nasty.benchmark --model pos_tagger_int8.axon
# => 18ms per sentence (2.5x faster)
```

### Accuracy Comparison

```bash
# Evaluate both models
mix nasty.eval --model models/pos_tagger.axon --test data/test.conllu
# => Accuracy: 97.8%

mix nasty.eval --model models/pos_tagger_int8.axon --test data/test.conllu
# => Accuracy: 97.4%  (0.4% degradation)
```

## Mix Tasks

### Quantize Existing Model

```bash
mix nasty.quantize \
  --model models/pos_tagger.axon \
  --calibration data/calibration.conllu \
  --method percentile \
  --output models/pos_tagger_int8.axon
```

### Evaluate Quantized Model

```bash
mix nasty.quantize.eval \
  --original models/pos_tagger.axon \
  --quantized models/pos_tagger_int8.axon \
  --test data/test.conllu
```

Output:
```
Comparing models on 2000 test examples:

Original (Float32):
  Accuracy: 97.84%
  Memory: 412MB
  Avg inference: 45.3ms

Quantized (INT8):
  Accuracy: 97.41%
  Memory: 108MB
  Avg inference: 18.2ms

Summary:
  Size reduction: 3.8x
  Speed improvement: 2.5x
  Accuracy loss: 0.43%
```

### Estimate Size Reduction

```bash
mix nasty.quantize.estimate --model models/pos_tagger.axon
```

Output:
```
Model: models/pos_tagger.axon
Parameters: 125,000,000

Estimated sizes:
  Float32 (current): 412 MB
  INT8: 108 MB (3.8x smaller)
  INT4: 58 MB (7.1x smaller)
  
Memory usage:
  Float32: ~1.2 GB (with activations)
  INT8: ~350 MB (70% reduction)
```

## Advanced Options

### Per-Channel Quantization

Quantize each output channel separately for better accuracy:

```elixir
INT8.quantize(model,
  calibration_data: data,
  per_channel: true  # Default
)
```

### Symmetric vs Asymmetric

**Symmetric** (default, faster):
```elixir
INT8.quantize(model, symmetric: true)
# Range: [-127, 127], zero_point = 0
```

**Asymmetric** (better accuracy):
```elixir
INT8.quantize(model, symmetric: false)
# Range: [-128, 127], zero_point = computed
```

### Selective Quantization

Quantize only certain layers:

```elixir
INT8.quantize(model,
  calibration_data: data,
  skip_layers: ["embedding", "output"]  # Keep these in Float32
)
```

## Deployment Strategies

### CPU Deployment

INT8 quantization provides maximum speedup on CPU:

```elixir
# Production inference
{:ok, model} = INT8.load("models/pos_tagger_int8.axon")

def tag_text(text) do
  {:ok, tokens} = Tokenizer.tokenize(text)
  {:ok, tagged} = INT8.predict(model, tokens)
  tagged
end
```

### GPU Deployment

Limited benefits on GPU (GPUs are optimized for Float32):

```elixir
# Use Float32 on GPU, INT8 on CPU
model = 
  if gpu_available?() do
    {:ok, m} = NeuralTagger.load("models/pos_tagger.axon")
    m
  else
    {:ok, m} = INT8.load("models/pos_tagger_int8.axon")
    m
  end
```

### Mobile/Edge Deployment

Essential for resource-constrained devices:

```elixir
# Aggressive quantization for mobile
{:ok, model} = INT8.quantize(full_model,
  calibration_data: data,
  calibration_method: :percentile,
  per_channel: true,
  compress: true  # Additional gzip compression
)

# Further optimize
{:ok, pruned} = Pruner.prune(model, sparsity: 0.3)
{:ok, distilled} = Distiller.distill(pruned, student_size: 0.5)
```

## Troubleshooting

### High Accuracy Loss

**Problem**: Accuracy drops >2% after quantization

**Solutions**:
1. Use more calibration data (increase from 100 to 1000 samples)
2. Switch to percentile method with higher percentile (99.99)
3. Use asymmetric quantization
4. Skip quantizing sensitive layers (embedding, output)
5. Try QAT for best accuracy

```elixir
# Better calibration
INT8.quantize(model,
  calibration_data: more_samples,  # 1000 instead of 100
  calibration_method: :percentile,
  percentile: 99.99,
  symmetric: false
)
```

### Slow Quantization

**Problem**: Calibration takes too long

**Solutions**:
1. Reduce calibration sample size
2. Use minmax instead of entropy method
3. Disable per-channel quantization

```elixir
# Faster quantization
INT8.quantize(model,
  calibration_data: fewer_samples,  # 100 instead of 1000
  calibration_method: :minmax,
  per_channel: false
)
```

### Large Model Size

**Problem**: INT8 model still too large

**Solutions**:
1. Apply model pruning first
2. Use knowledge distillation
3. Consider INT4 quantization (more aggressive)

```elixir
# Aggressive optimization pipeline
{:ok, pruned} = Pruner.prune(model, sparsity: 0.4)
{:ok, quantized} = INT8.quantize(pruned, calibration_data: data)
{:ok, compressed} = Compressor.compress(quantized, method: :gzip)
```

## Best Practices

### 1. Always Validate Accuracy

```elixir
# Validate before deploying
{:ok, quantized} = INT8.quantize(model,
  calibration_data: data,
  target_accuracy_loss: 0.01  # Fail if >1% loss
)
```

### 2. Use Representative Calibration Data

```elixir
# BAD: Only formal text
calibration_data = load_samples("formal_documents.txt")

# GOOD: Mixed domains matching production
calibration_data = 
  load_samples("news.txt", 100) ++
  load_samples("social_media.txt", 100) ++
  load_samples("technical.txt", 100)
```

### 3. Benchmark in Production Environment

```bash
# Test on actual deployment hardware
mix nasty.benchmark \
  --model models/pos_tagger_int8.axon \
  --environment production \
  --samples 1000
```

### 4. Version Your Quantized Models

```
models/
  pos_tagger_v1_fp32.axon         # Original
  pos_tagger_v1_int8_minmax.axon  # Quick quantization
  pos_tagger_v1_int8_percentile.axon  # Production quantization
  pos_tagger_v1_qat.axon          # Quantization-aware trained
```

## Performance Metrics

### POS Tagging (UD English)

| Model | Size | Inference (CPU) | Accuracy | Use Case |
|-------|------|----------------|----------|----------|
| Float32 | 412MB | 45ms | 97.8% | GPU servers |
| INT8 (minmax) | 108MB | 19ms | 97.2% | Fast deployment |
| INT8 (percentile) | 108MB | 18ms | 97.4% | Production |
| INT8 QAT | 108MB | 18ms | 97.8% | Critical apps |

### NER (CoNLL-2003)

| Model | Size | Inference (CPU) | F1 Score | Use Case |
|-------|------|----------------|----------|----------|
| Float32 | 380MB | 52ms | 94.2% | Research |
| INT8 | 98MB | 21ms | 93.5% | Production |

## See Also

- [NEURAL_MODELS.md](NEURAL_MODELS.md) - Neural architecture details
- [FINE_TUNING.md](FINE_TUNING.md) - Training custom models
- [PRETRAINED_MODELS.md](PRETRAINED_MODELS.md) - Using transformers
- [Model Compression Papers](https://arxiv.org/abs/2010.03954)
