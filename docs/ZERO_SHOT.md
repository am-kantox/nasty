# Zero-shot Classification Guide

Complete guide to zero-shot text classification in Nasty using Natural Language Inference models.

## Overview

Zero-shot classification allows you to classify text into **arbitrary categories without any training data**. It works by framing classification as a Natural Language Inference (NLI) problem.

**Key Benefits:**
- No training data required
- Works with any label set you define
- Add new categories instantly
- Multi-label classification support
- 70-85% accuracy on many tasks

## How It Works

The model treats classification as textual entailment:

1. **Hypothesis**: "This text is about {label}"
2. **Premise**: Your input text
3. **Prediction**: Probability that premise entails hypothesis

For each candidate label, the model predicts entailment probability. The label with highest probability wins.

### Example

**Text**: "I love this product!"

**Labels**: positive, negative, neutral

**Process**:
- "I love this product!" entails "This text is about positive" → 95%
- "I love this product!" entails "This text is about negative" → 2%
- "I love this product!" entails "This text is about neutral" → 3%

**Result**: positive (95% confidence)

## Quick Start

### CLI Usage

```bash
# Single text classification
mix nasty.zero_shot \
  --text "I love this product!" \
  --labels positive,negative,neutral

# Output:
# Text: I love this product!
#   Predicted: positive
#   Confidence: 95.3%
#
#   All scores:
#     positive: 95.3% ████████████████████
#     neutral:   3.2% █
#     negative:  1.5%
```

### Programmatic Usage

```elixir
alias Nasty.Statistics.Neural.Transformers.ZeroShot

{:ok, result} = ZeroShot.classify("I love this product!",
  candidate_labels: ["positive", "negative", "neutral"]
)

# result = %{
#   label: "positive",
#   scores: %{
#     "positive" => 0.953,
#     "neutral" => 0.032,
#     "negative" => 0.015
#   },
#   sequence: "I love this product!"
# }
```

## Common Use Cases

### 1. Sentiment Analysis

```bash
mix nasty.zero_shot \
  --text "The movie was boring and predictable" \
  --labels positive,negative,neutral
```

**Why it works**: Clear emotional content maps well to sentiment labels.

### 2. Topic Classification

```bash
mix nasty.zero_shot \
  --text "Bitcoin reaches new all-time high" \
  --labels technology,finance,sports,politics,business
```

**Why it works**: Topics have distinct semantic spaces.

### 3. Intent Detection

```bash
mix nasty.zero_shot \
  --text "Can you help me reset my password?" \
  --labels question,request,complaint,praise
```

**Why it works**: Intents have characteristic linguistic patterns.

### 4. Content Moderation

```bash
mix nasty.zero_shot \
  --text "This is the worst service ever!!!" \
  --labels spam,offensive,normal,promotional
```

**Why it works**: Moderation categories have clear signals.

### 5. Email Routing

```bash
mix nasty.zero_shot \
  --text "Urgent: Server down in production" \
  --labels urgent,normal,low_priority,informational
```

**Why it works**: Urgency and importance have lexical markers.

## Multi-label Classification

Assign multiple labels when appropriate:

```bash
mix nasty.zero_shot \
  --text "Urgent: Please review the attached technical document" \
  --labels urgent,action_required,informational,technical \
  --multi-label \
  --threshold 0.5
```

**Output**:
```
Predicted labels: urgent, action_required, technical

All scores:
  [✓] urgent:          0.89
  [✓] action_required: 0.76
  [✓] technical:       0.68
  [ ] informational:   0.34
```

Only labels above threshold (0.5) are selected.

### Multi-label Use Cases

- **Document tagging**: Tag with multiple topics
- **Email categorization**: Both "urgent" AND "technical"
- **Content flags**: Multiple moderation issues
- **Skill extraction**: Multiple skills from job description

## Batch Classification

Process multiple texts efficiently:

```bash
# Create input file
cat > texts.txt << EOF
I love this product!
The service was terrible
It's okay, nothing special
EOF

# Classify batch
mix nasty.zero_shot \
  --input texts.txt \
  --labels positive,negative,neutral \
  --output results.json
```

Result saved to `results.json`:
```json
[
  {
    "text": "I love this product!",
    "result": {
      "label": "positive",
      "scores": {"positive": 0.95, "neutral": 0.03, "negative": 0.02}
    },
    "success": true
  },
  ...
]
```

## Supported Models

### RoBERTa-MNLI (Default)

**Best for**: English text, highest accuracy

```bash
--model roberta_large_mnli
```

**Specs**:
- Parameters: 355M
- Languages: English only
- Accuracy: 85-90% on many tasks
- Speed: Medium

### BART-MNLI

**Best for**: Alternative to RoBERTa, slightly different strengths

```bash
--model bart_large_mnli
```

**Specs**:
- Parameters: 400M
- Languages: English only
- Accuracy: 83-88%
- Speed: Slower than RoBERTa

### XLM-RoBERTa

**Best for**: Multilingual (Spanish, Catalan, etc.)

```bash
--model xlm_roberta_base
```

**Specs**:
- Parameters: 270M
- Languages: 100 languages
- Accuracy: 75-85% (varies by language)
- Speed: Fast

## Custom Hypothesis Templates

Change how classification is framed:

```bash
# Default template
--hypothesis-template "This text is about {}"

# Custom templates
--hypothesis-template "This message is {}"
--hypothesis-template "The sentiment is {}"
--hypothesis-template "The topic of this text is {}"
--hypothesis-template "This document contains {}"
```

**Example**:

```bash
mix nasty.zero_shot \
  --text "Please call me back ASAP" \
  --labels urgent,normal,low_priority \
  --hypothesis-template "This message is {}"
```

Generates hypotheses:
- "This message is urgent"
- "This message is normal"
- "This message is low_priority"

## Best Practices

### 1. Choose Clear, Distinct Labels

**Good**:
```bash
--labels positive,negative,neutral
--labels urgent,normal,low_priority
--labels technical,business,personal
```

**Bad** (too similar):
```bash
--labels happy,joyful,cheerful  # Too similar!
--labels important,critical,essential  # Overlapping!
```

### 2. Use Descriptive Label Names

**Good**:
```bash
--labels positive_sentiment,negative_sentiment,neutral_sentiment
```

**Better**:
```bash
--labels positive,negative,neutral  # Simpler, but clear
```

**Bad**:
```bash
--labels pos,neg,neu  # Too cryptic
--labels 1,2,3  # Meaningless
```

### 3. Provide 2-6 Labels

- **Too few** (1 label): Not classification
- **Sweet spot** (2-6 labels): Best accuracy
- **Too many** (10+ labels): Accuracy degrades

### 4. Use Multi-label for Overlapping Concepts

**Single-label** (mutually exclusive):
```bash
--labels positive,negative,neutral
```

**Multi-label** (can overlap):
```bash
--labels urgent,technical,action_required,informational \
--multi-label
```

### 5. Adjust Threshold for Multi-label

```bash
# Conservative (fewer labels)
--threshold 0.7

# Balanced (default)
--threshold 0.5

# Liberal (more labels)
--threshold 0.3
```

## Performance Tips

### When Zero-shot Works Best

✓ Clear semantic categories  
✓ 2-6 distinct labels  
✓ Labels have characteristic language patterns  
✓ English text (for RoBERTa-MNLI)  
✓ Medium-length text (10-200 words)

### When to Use Fine-tuning Instead

✗ Need >90% accuracy  
✗ Domain-specific jargon  
✗ Subtle distinctions between labels  
✗ Have 1000+ labeled examples  
✗ Production critical system

Zero-shot is great for prototyping and low-stakes classification. For production, consider fine-tuning.

## Limitations

### 1. Language Dependence

RoBERTa-MNLI only works well for English. For other languages:

```bash
# Spanish/Catalan
--model xlm_roberta_base
```

Expect 10-15% lower accuracy than English.

### 2. Accuracy Ceiling

Zero-shot typically achieves 70-85% accuracy. Fine-tuning can reach 95-99%.

### 3. Context Window

Models have maximum input length (~512 tokens). Long documents need truncation:

```bash
# Truncate to first 512 tokens automatically
--max-length 512
```

### 4. Label Sensitivity

Results can vary with label phrasing:

```bash
# These may give different results:
--labels positive,negative
--labels good,bad
--labels happy,sad
```

Test different phrasings to find what works best.

## Troubleshooting

### All Scores Are Similar

**Problem**: Scores like 0.33, 0.34, 0.33 (no clear winner)

**Causes**:
- Labels are too similar
- Text is ambiguous
- Poor hypothesis template

**Solutions**:
1. Use more distinct labels
2. Try different hypothesis template
3. Add more context to text
4. Consider if text is truly ambiguous

### Wrong Label Predicted

**Problem**: Clearly wrong prediction

**Causes**:
- Label phrasing doesn't match text semantics
- Need different hypothesis template
- Text is out-of-domain for model

**Solutions**:
1. Rephrase labels
2. Change hypothesis template
3. Try different model
4. Consider fine-tuning for your domain

### Slow Performance

**Problem**: Classification takes too long

**Solutions**:
1. Use smaller model (xlm_roberta_base vs roberta_large)
2. Enable GPU (set XLA_TARGET=cuda)
3. Reduce number of labels
4. Use batch processing for multiple texts

## Advanced Usage

### Programmatic Batch Processing

```elixir
alias Nasty.Statistics.Neural.Transformers.ZeroShot

texts = [
  "I love this!",
  "Terrible service",
  "It's okay"
]

{:ok, results} = ZeroShot.classify_batch(texts,
  candidate_labels: ["positive", "negative", "neutral"]
)

# results = [
#   %{label: "positive", scores: %{...}, sequence: "I love this!"},
#   %{label: "negative", scores: %{...}, sequence: "Terrible service"},
#   %{label: "neutral", scores: %{...}, sequence: "It's okay"}
# ]
```

### Confidence Thresholding

Reject low-confidence predictions:

```elixir
{:ok, result} = ZeroShot.classify(text,
  candidate_labels: ["positive", "negative", "neutral"]
)

max_score = result.scores[result.label]

if max_score < 0.6 do
  # Too uncertain, flag for human review
  {:uncertain, result}
else
  {:confident, result}
end
```

### Hierarchical Classification

First classify broadly, then refine:

```elixir
# Step 1: Broad category
{:ok, broad} = ZeroShot.classify(text,
  candidate_labels: ["product", "service", "support"]
)

# Step 2: Specific subcategory
specific_labels = case broad.label do
  "product" -> ["quality", "price", "features"]
  "service" -> ["delivery", "installation", "maintenance"]
  "support" -> ["technical", "billing", "general"]
end

{:ok, specific} = ZeroShot.classify(text,
  candidate_labels: specific_labels
)
```

## Comparison with Other Methods

| Method | Training Data | Accuracy | Setup Time | Flexibility |
|--------|---------------|----------|------------|-------------|
| Zero-shot | 0 examples | 70-85% | Instant | Very high |
| Few-shot | 10-100 examples | 80-90% | Minutes | High |
| Fine-tuning | 1000+ examples | 95-99% | Hours | Medium |
| Rule-based | N/A | 60-80% | Days | Low |

**Recommendation**: Start with zero-shot, move to fine-tuning if accuracy is insufficient.

## Production Deployment

### Caching Results

```elixir
defmodule ClassificationCache do
  use GenServer
  
  def classify_cached(text, labels) do
    cache_key = :crypto.hash(:md5, text <> Enum.join(labels)) |> Base.encode16()
    
    case get_cache(cache_key) do
      nil ->
        {:ok, result} = ZeroShot.classify(text, candidate_labels: labels)
        put_cache(cache_key, result)
        result
      
      cached ->
        cached
    end
  end
end
```

### Rate Limiting

```elixir
defmodule RateLimiter do
  def classify_with_limit(text, labels) do
    case check_rate_limit() do
      :ok ->
        ZeroShot.classify(text, candidate_labels: labels)
      
      {:error, :rate_limited} ->
        {:error, "Too many requests, please retry later"}
    end
  end
end
```

### Fallback Strategies

```elixir
def classify_robust(text, labels) do
  case ZeroShot.classify(text, candidate_labels: labels) do
    {:ok, result} ->
      if result.scores[result.label] > 0.6 do
        {:ok, result}
      else
        # Fall back to simpler method
        naive_bayes_classify(text, labels)
      end
    
    {:error, _} ->
      # Model unavailable, use rule-based
      rule_based_classify(text, labels)
  end
end
```

## See Also

- [FINE_TUNING.md](FINE_TUNING.md) - Train models for higher accuracy
- [CROSS_LINGUAL.md](CROSS_LINGUAL.md) - Multilingual classification
- [PRETRAINED_MODELS.md](PRETRAINED_MODELS.md) - Available transformer models
