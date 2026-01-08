# Grammar Customization Guide

This document explains how to customize and extend Nasty's grammar rules by creating external grammar resource files.

## Overview

Starting with version 0.2.0, Nasty externalizes grammar rules from hardcoded Elixir modules into configurable `.exs` resource files. This allows you to:

- Customize existing grammar rules without modifying source code
- Create domain-specific grammar variants (e.g., legal, medical, technical)
- Add support for new languages
- A/B test different parsing strategies
- Share grammar rule sets across projects

## Architecture

Grammar rules are stored as Elixir term files (`.exs`) in:

```
priv/languages/{language_code}/grammars/{rule_type}.exs
```

For variants (e.g., formal, informal, technical):

```
priv/languages/{language_code}/variants/{variant_name}/{rule_type}.exs
```

### Language Codes

- English: `en` or `english`
- Spanish: `es` or `spanish`
- Catalan: `ca` or `catalan` (future)

### Rule Types

Each language can have the following grammar rule files:

1. `phrase_rules.exs` - Phrase structure patterns (NP, VP, PP, AdjP, AdvP)
2. `dependency_rules.exs` - Universal Dependencies relations and extraction rules
3. `coordination_rules.exs` - Coordinating conjunctions and coordination patterns
4. `subordination_rules.exs` - Subordinating conjunctions and subordinate clause patterns

## Grammar Loader API

### Loading Grammar Rules

```elixir
alias Nasty.Language.GrammarLoader

# Load default grammar rules
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules)

# Load with variant
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules, variant: "formal")

# Force reload (bypass cache)
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules, force_reload: true)
```

### Cache Management

```elixir
# Clear all cached grammar
GrammarLoader.clear_cache()

# Clear specific cached rules
GrammarLoader.clear_cache(:en, :phrase_rules, :default)
```

### Direct File Loading

```elixir
# Load from custom path
{:ok, rules} = GrammarLoader.load_file("/path/to/custom_rules.exs")
```

## Creating Grammar Files

### File Structure

Grammar files are Elixir term files that evaluate to a map:

```elixir
%{
  # Top-level keys define rule categories
  rule_category_1: [...],
  rule_category_2: %{...},
  
  # Metadata
  notes: %{
    key: "description"
  }
}
```

### Example: Simple Phrase Rules

Create `priv/languages/en/grammars/custom_phrase_rules.exs`:

```elixir
%{
  # Noun phrase patterns
  noun_phrases: [
    # Simple NP: Det + Noun
    {:np, [:det, :noun]},
    
    # NP with adjective: Det + Adj + Noun
    {:np, [:det, :adj, :noun]},
    
    # NP with PP: Det + Noun + PP
    {:np, [:det, :noun, :pp]}
  ],
  
  # Verb phrase patterns
  verb_phrases: [
    # Simple VP: just Verb
    {:vp, [:verb]},
    
    # VP with object: Verb + NP
    {:vp, [:verb, :np]},
    
    # VP with auxiliary: Aux + Verb
    {:vp, [:aux, :verb]}
  ],
  
  notes: %{
    version: "1.0.0",
    author: "Your Name",
    description: "Custom phrase rules for domain-specific parsing"
  }
}
```

## English Grammar Reference

### Phrase Rules (`phrase_rules.exs`)

See `priv/languages/en/grammars/phrase_rules.exs` for the complete reference.

Key sections:

```elixir
%{
  noun_phrases: [
    # List of NP patterns
    {:np, [:det, :noun]},
    {:np, [:det, :adj, :noun]},
    # ...
  ],
  
  verb_phrases: [
    # List of VP patterns
    {:vp, [:verb]},
    {:vp, [:aux, :verb, :np]},
    # ...
  ],
  
  prepositional_phrases: [
    # PP patterns
    {:pp, [:prep, :np]},
    # ...
  ],
  
  adjectival_phrases: [
    # AdjP patterns
    {:adjp, [:adv, :adj]},
    # ...
  ],
  
  adverbial_phrases: [
    # AdvP patterns
    {:advp, [:adv]},
    # ...
  ],
  
  relative_clauses: [
    # Relative clause patterns
    {:relative_clause, [:relative_marker, :clause]},
    # ...
  ],
  
  special_rules: [
    # Special handling rules
    {:comparative_than, :pseudo_prep},
    # ...
  ]
}
```

### Dependency Rules (`dependency_rules.exs`)

See `priv/languages/en/grammars/dependency_rules.exs` for the complete reference.

Key sections:

```elixir
%{
  core_arguments: [
    # Subject, object, complements
    %{
      relation: :nsubj,
      description: "Nominal subject",
      head_pos: [:verb],
      dependent_pos: [:noun, :propn, :pron],
      example: "The cat sleeps → nsubj(sleeps, cat)"
    },
    # ...
  ],
  
  nominal_dependents: [
    # Determiners, modifiers
    %{relation: :det, ...},
    %{relation: :amod, ...},
    # ...
  ],
  
  function_words: [
    # Auxiliaries, copulas, markers
    %{relation: :aux, ...},
    # ...
  ],
  
  extraction_priorities: [
    # Order of dependency extraction
    :nsubj, :obj, :det, :amod, # ...
  ]
}
```

### Coordination Rules (`coordination_rules.exs`)

Key sections:

```elixir
%{
  coordinating_conjunctions: [
    %{
      conjunction: "and",
      type: :copulative,
      example: "cats and dogs"
    },
    # ...
  ],
  
  coordination_patterns: [
    %{
      pattern: :np_coordination,
      structure: "NP CCONJ NP",
      example: "cats and dogs"
    },
    # ...
  ],
  
  special_cases: [
    # Correlative conjunctions, etc.
    %{
      type: :correlative,
      patterns: [
        %{pair: ["both", "and"], example: "both cats and dogs"},
        # ...
      ]
    }
  ]
}
```

### Subordination Rules (`subordination_rules.exs`)

Key sections:

```elixir
%{
  subordinating_conjunctions: [
    %{
      conjunction: "because",
      type: :causal,
      example: "I stayed because it rained"
    },
    # ...
  ],
  
  relative_markers: [
    %{
      marker: "who",
      type: :relative_pronoun,
      example: "the person who came"
    },
    # ...
  ],
  
  subordinate_clause_types: [
    %{
      type: :adverbial,
      dependency_relation: :advcl,
      subtypes: [:temporal, :causal, :conditional, ...]
    },
    # ...
  ]
}
```

## Spanish Grammar Reference

Spanish grammar files follow the same structure but include Spanish-specific features:

- Post-nominal adjectives: `la casa roja` (the red house)
- Pro-drop: null subjects allowed
- Flexible word order: SVO, VSO, VOS
- Clitic pronouns: `dámelo` (give-me-it)
- Personal 'a': `Veo a Juan` (I see Juan)
- Two copulas: `ser` vs. `estar`
- Phonetic variants: `y`→`e`, `o`→`u` before vowels

See files in `priv/languages/es/grammars/` for complete Spanish grammar.

## Creating Domain-Specific Variants

### Example: Technical English

Create `priv/languages/en/variants/technical/phrase_rules.exs`:

```elixir
%{
  # Inherit base rules and add technical-specific patterns
  noun_phrases: [
    # Standard patterns
    {:np, [:det, :noun]},
    
    # Technical compound nouns (e.g., "TCP/IP protocol")
    {:np, [:propn, :noun]},
    {:np, [:propn, :sym, :propn, :noun]},
    
    # Noun phrases with technical modifiers
    {:np, [:num, {:unit, [:noun]}, :noun]},  # "5 GB memory"
    
    # Multi-word technical terms
    {:np, [{:many, :noun}]}  # "machine learning model"
  ],
  
  verb_phrases: [
    # Standard patterns
    {:vp, [:verb, :np]},
    
    # Technical action verbs (instantiate, serialize, etc.)
    {:vp, [:tech_verb, :np, :pp]},
    
    # Passive constructions common in technical writing
    {:vp, [:aux, :verb, :pp]}
  ],
  
  notes: %{
    domain: "technical",
    use_case: "Software documentation, API specs, technical papers"
  }
}
```

### Example: Legal English

```elixir
%{
  noun_phrases: [
    # Legal entities
    {:np, [:det, :legal_entity]},  # "the plaintiff", "the defendant"
    
    # Complex legal terms
    {:np, [:det, :adj, :legal_term, :pp]},  # "the aforementioned contractual obligation"
    
    # References (Section X, Article Y)
    {:np, [:legal_ref_type, :num]}  # "Section 5"
  ],
  
  subordination_patterns: [
    # Legal conditionals (provided that, in the event that)
    {:conditional, :multiword_legal_conj}
  ],
  
  notes: %{
    domain: "legal",
    use_case: "Contracts, legislation, court documents"
  }
}
```

## Using Custom Grammar in Code

### Option 1: Load and Use Directly

```elixir
# Load custom grammar
{:ok, custom_phrase_rules} = GrammarLoader.load(:en, :custom_phrase_rules)

# Use in your parser
custom_np_patterns = custom_phrase_rules.noun_phrases
# Process with custom patterns...
```

### Option 2: Extend Parser Module

```elixir
defmodule MyApp.CustomParser do
  alias Nasty.Language.GrammarLoader
  
  def parse_technical_text(text) do
    # Load technical variant
    {:ok, rules} = GrammarLoader.load(:en, :phrase_rules, variant: "technical")
    
    # Parse using custom rules
    # ... your parsing logic using rules ...
  end
end
```

### Option 3: Runtime Configuration

```elixir
# In config/config.exs
config :nasty,
  default_grammar_variant: "technical"

# In your code
variant = Application.get_env(:nasty, :default_grammar_variant, :default)
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules, variant: variant)
```

## Grammar Validation

The grammar loader validates that all files return a map:

```elixir
# Valid
%{
  rules: [...],
  notes: %{}
}

# Invalid - will raise error
[1, 2, 3]  # Not a map
```

For more complex validation, extend `GrammarLoader.validate_rules/1`.

## Best Practices

### 1. Start with Base Grammar

Copy existing grammar files and modify rather than starting from scratch:

```bash
cp priv/languages/en/grammars/phrase_rules.exs \
   priv/languages/en/variants/custom/phrase_rules.exs
```

### 2. Document Your Rules

Include comprehensive notes in your grammar files:

```elixir
%{
  rules: [...],
  
  notes: %{
    version: "1.0.0",
    author: "Team Name",
    created: "2026-01-08",
    description: "Custom grammar for medical text parsing",
    changes: [
      "Added medical entity patterns",
      "Extended VP patterns for medical procedures"
    ],
    examples: [
      "The patient underwent cardiac catheterization",
      "Diagnose: Type 2 diabetes mellitus"
    ]
  }
}
```

### 3. Test Your Grammar

Create tests for custom grammar:

```elixir
defmodule MyApp.CustomGrammarTest do
  use ExUnit.Case
  alias Nasty.Language.GrammarLoader
  
  test "custom grammar loads successfully" do
    assert {:ok, rules} = GrammarLoader.load(:en, :custom_rules)
    assert is_map(rules)
    assert Map.has_key?(rules, :noun_phrases)
  end
  
  test "custom grammar includes domain patterns" do
    {:ok, rules} = GrammarLoader.load(:en, :custom_rules, variant: "medical")
    assert Enum.any?(rules.noun_phrases, fn pattern ->
      # Check for medical-specific patterns
    end)
  end
end
```

### 4. Version Your Grammar

Track grammar versions for reproducibility:

```elixir
%{
  metadata: %{
    version: "2.1.0",
    compatible_with: "nasty >= 0.2.0"
  },
  # ... rules ...
}
```

### 5. Keep Grammar Files Focused

Separate concerns across different rule types:

- Phrase structure → `phrase_rules.exs`
- Dependencies → `dependency_rules.exs`
- Coordination → `coordination_rules.exs`
- Subordination → `subordination_rules.exs`

Don't mix all rules into one file.

## Performance Considerations

### Caching

Grammar files are cached in ETS after first load:

```elixir
# First load: reads from disk
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules)  # ~5ms

# Subsequent loads: from cache
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules)  # ~0.1ms
```

Clear cache when updating grammar during development:

```elixir
GrammarLoader.clear_cache()
```

### File Size

Keep grammar files under 1MB for fast loading. If needed, split into multiple files:

```
phrase_rules_np.exs  # Noun phrase patterns
phrase_rules_vp.exs  # Verb phrase patterns
phrase_rules_pp.exs  # Prepositional phrase patterns
```

## Troubleshooting

### Grammar File Not Found

```
Grammar file not found: .../en/grammars/missing_rules.exs, using empty rules
```

**Solution**: Check file exists and path is correct. Grammar files must be in `priv/languages/{lang}/grammars/`.

### Invalid Grammar Format

```
** (ArgumentError) Grammar rules must be a map, got: [...]
```

**Solution**: Ensure file evaluates to a map:

```elixir
# Correct
%{rules: [...]}

# Wrong
[...]
```

### Compilation Errors

```
** (SyntaxError) invalid syntax
```

**Solution**: Grammar files must be valid Elixir. Test with:

```bash
elixir priv/languages/en/grammars/your_rules.exs
```

### Cache Issues

If changes to grammar files aren't reflected:

```elixir
# Clear cache
Nasty.Language.GrammarLoader.clear_cache()

# Or force reload
{:ok, rules} = GrammarLoader.load(:en, :phrase_rules, force_reload: true)
```

## Examples Repository

See working examples in the main repository:

- English grammar: `priv/languages/en/grammars/`
- Spanish grammar: `priv/languages/es/grammars/`
- Test fixtures: `test/fixtures/grammars/`

## Contributing Custom Grammars

To contribute grammar variants to the Nasty project:

1. Create grammar files following the structure above
2. Add tests demonstrating the grammar works
3. Document the use case and domain
4. Submit a pull request to the main repository

## Further Reading

- [PARSING_GUIDE.md](PARSING_GUIDE.md) - Understanding the parsing pipeline
- [ENGLISH_GRAMMAR.md](languages/ENGLISH_GRAMMAR.md) - English grammar specification
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- Universal Dependencies: https://universaldependencies.org/
