#!/bin/bash

# Quick Start Script for Training HMM POS Model
# This script downloads Universal Dependencies English-EWT and trains a model

set -e

echo "=== Nasty Quick Model Training ==="
echo ""

# Check if mix is available
if ! command -v mix &> /dev/null; then
    echo "Error: Elixir/Mix not found. Please install Elixir first."
    exit 1
fi

# Create data directory
echo "Creating data directory..."
mkdir -p data
cd data

# Download Universal Dependencies English-EWT
if [ ! -d "UD_English-EWT-r2.13" ]; then
    echo "Downloading Universal Dependencies English-EWT v2.13..."
    wget -q https://github.com/UniversalDependencies/UD_English-EWT/archive/refs/tags/r2.13.tar.gz
    echo "Extracting corpus..."
    tar -xzf r2.13.tar.gz
    rm r2.13.tar.gz
    echo "Corpus downloaded successfully!"
else
    echo "Corpus already exists, skipping download."
fi

cd ..

# Create models directory
mkdir -p priv/models/en

# Train the model
echo ""
echo "Training HMM POS model (this may take 30-60 seconds)..."
echo ""

mix nasty.train.pos \
  --corpus data/UD_English-EWT-r2.13/en_ewt-ud-train.conllu \
  --dev data/UD_English-EWT-r2.13/en_ewt-ud-dev.conllu \
  --test data/UD_English-EWT-r2.13/en_ewt-ud-test.conllu \
  --output priv/models/en/pos_hmm_v1.model \
  --smoothing 0.001

echo ""
echo "=== Training Complete! ==="
echo ""
echo "Model saved to: priv/models/en/pos_hmm_v1.model"
echo ""
echo "To use your trained model:"
echo "  {:ok, ast} = Nasty.parse(\"Your text here\", language: :en, model: :hmm)"
echo ""
echo "To list available models:"
echo "  mix nasty.models list"
echo ""
