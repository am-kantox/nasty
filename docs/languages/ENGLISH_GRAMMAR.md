# English Grammar Specification

This document provides a comprehensive formal specification of English grammar as implemented in Nasty. It serves as the authoritative reference for the English language parser implementation.

## Table of Contents

1. [Part-of-Speech Tags](#part-of-speech-tags)
2. [Phrase Structure Rules](#phrase-structure-rules)
3. [Dependency Relations](#dependency-relations)
4. [Morphological Features](#morphological-features)
5. [Sentence Types](#sentence-types)
6. [Lexical Categories](#lexical-categories)

## Part-of-Speech Tags

Nasty uses the Universal Dependencies (UD) part-of-speech tagset.

### Open Class Words

| Tag | Name | Description | Examples |
|-----|------|-------------|----------|
| `ADJ` | Adjective | Modifies nouns | big, old, green, first |
| `ADV` | Adverb | Modifies verbs, adjectives, other adverbs | very, well, exactly, quickly |
| `NOUN` | Noun | Common nouns | cat, tree, idea, happiness |
| `PROPN` | Proper Noun | Names of specific entities | London, Mary, Monday |
| `VERB` | Verb | Main verbs (content verbs) | run, eat, think, destroy |

### Closed Class Words

| Tag | Name | Description | Examples |
|-----|------|-------------|----------|
| `ADP` | Adposition | Prepositions (English has no postpositions) | in, on, at, by, for, with, from, to, of, about |
| `AUX` | Auxiliary | Auxiliary and modal verbs | be, have, do, will, can, should, must |
| `CCONJ` | Coordinating Conjunction | Coordinates words, phrases, or clauses | and, or, but, nor, yet, so, for |
| `DET` | Determiner | Determiners (articles, demonstratives, quantifiers) | the, a, an, this, that, some, any, all, my, your |
| `INTJ` | Interjection | Exclamations | oh, wow, hey, oops, ugh |
| `NUM` | Numeral | Numbers (cardinal and ordinal) | one, two, 1, 2, first, second |
| `PART` | Particle | Verb particles | up, down, out, off, away |
| `PRON` | Pronoun | Personal, possessive, demonstrative, interrogative pronouns | I, you, he, she, it, we, they, who, which, this, that |
| `PUNCT` | Punctuation | Punctuation marks | . , ; : ! ? ( ) [ ] " ' - |
| `SCONJ` | Subordinating Conjunction | Introduces subordinate clauses | because, if, when, while, although, since, unless |
| `X` | Other | Unclassified or unknown | |

### POS Tag Mapping in Code

In `lib/language/english/pos_tagger.ex`, tags are represented as atoms:

```elixir
:adj, :adv, :noun, :propn, :verb,
:adp, :aux, :cconj, :det, :intj,
:num, :part, :pron, :punct, :sconj, :x
```

## Phrase Structure Rules

Nasty uses a simplified Context-Free Grammar (CFG) for phrase parsing.

### Formal CFG Rules

```cfg
# Sentence Level
S    → CLAUSE+ PUNCT
SENT → MAIN_CLAUSE COORD_CLAUSE* SUBORD_CLAUSE*

# Clause Level
MAIN_CLAUSE   → NP VP
COORD_CLAUSE  → CCONJ NP VP
SUBORD_CLAUSE → SCONJ NP? VP

# Phrase Level
NP   → DET? ADJ* (NOUN | PROPN | PRON) PP* RC*
VP   → AUX* VERB NP? PP* ADVP*
PP   → ADP NP
ADJP → ADV? ADJ
ADVP → ADV+
RC   → REL_PRON_ADV CLAUSE

# Terminal Symbols
DET       → the | a | an | this | that | some | my | ...
ADJ       → big | small | happy | fast | ...
NOUN      → cat | dog | tree | idea | ...
PROPN     → London | Mary | Monday | ...
PRON      → I | you | he | she | it | we | they | ...
VERB      → run | eat | think | walk | ...
AUX       → be | have | do | will | can | should | ...
ADP       → in | on | at | by | for | with | ...
CCONJ     → and | or | but | ...
SCONJ     → because | if | when | while | ...
ADV       → very | quickly | often | well | ...
REL_PRON_ADV → who | whom | whose | which | that | where | when | why
```

### Phrase Structure Detailed Specifications

#### Noun Phrase (NP)

**Structure**: `DET? ADJ* HEAD POST_MOD*`

**Components**:
1. **Determiner** (optional): DET
   - Articles: `the`, `a`, `an`
   - Demonstratives: `this`, `that`, `these`, `those`
   - Possessives: `my`, `your`, `his`, `her`, `its`, `our`, `their`
   - Quantifiers: `some`, `any`, `every`, `each`, `all`, `both`, `many`, `much`, `few`, `several`

2. **Pre-modifiers** (0 or more): ADJ*
   - Adjectives: `big`, `old`, `happy`
   - PROPN (for multi-word names): `New` in "New York"

3. **Head** (required): NOUN | PROPN | PRON
   - Common noun: `cat`, `tree`, `happiness`
   - Proper noun: `London`, `Mary`
   - Pronoun: `I`, `you`, `he`, `she`, `it`, `we`, `they`

4. **Post-modifiers** (0 or more): PP* | RC*
   - Prepositional phrases: `on the mat`, `in the house`
   - Relative clauses: `that sits`, `who I know`

**Examples**:
```
"the cat"                    → [DET, NOUN]
"the big cat"                → [DET, ADJ, NOUN]
"the big black cat"          → [DET, ADJ, ADJ, NOUN]
"the cat on the mat"         → [DET, NOUN, PP]
"the cat that sits"          → [DET, NOUN, RC]
"New York"                   → [PROPN, PROPN]
"I"                          → [PRON]
```

#### Verb Phrase (VP)

**Structure**: `AUX* MAIN_VERB COMPLEMENT*`

**Components**:
1. **Auxiliaries** (0 or more): AUX*
   - Be: `am`, `is`, `are`, `was`, `were`, `be`, `been`, `being`
   - Have: `have`, `has`, `had`, `having`
   - Do: `do`, `does`, `did`
   - Modals: `will`, `would`, `shall`, `should`, `can`, `could`, `may`, `might`, `must`, `ought`

2. **Main Verb** (required): VERB
   - Action: `run`, `eat`, `write`, `think`
   - State: `be`, `seem`, `appear`, `know`

3. **Complements** (0 or more):
   - Direct object (NP): `the cat`
   - Prepositional phrase (PP): `on the mat`
   - Adverbial phrase (ADVP): `quickly`, `very fast`

**Examples**:
```
"runs"                       → [VERB]
"is running"                 → [AUX, VERB]
"will have been running"     → [AUX, AUX, AUX, VERB]
"eats the food"              → [VERB, NP]
"sits on the mat"            → [VERB, PP]
"runs quickly"               → [VERB, ADVP]
"gave the book to Mary"      → [VERB, NP, PP]
```

**Copula Constructions**:

When no main verb is present, the last auxiliary serves as the main verb:
```
"is happy"        → [AUX-as-VERB, ADJP]
"are engineers"   → [AUX-as-VERB, NP]
"was in the house" → [AUX-as-VERB, PP]
```

#### Prepositional Phrase (PP)

**Structure**: `PREPOSITION NP`

**Prepositions**:
- Location: `in`, `on`, `at`, `inside`, `above`, `below`, `behind`, `beside`, `between`
- Direction: `to`, `from`, `toward`, `into`, `through`, `across`, `along`
- Time: `at`, `on`, `in`, `during`, `before`, `after`, `since`, `until`
- Other: `of`, `by`, `with`, `for`, `about`, `without`

**Examples**:
```
"on the mat"      → [ADP, NP("the mat")]
"in the house"    → [ADP, NP("the house")]
"to New York"     → [ADP, NP("New York")]
"with a smile"    → [ADP, NP("a smile")]
```

#### Adjectival Phrase (ADJP)

**Structure**: `INTENSIFIER? ADJ`

**Intensifiers** (optional): ADV
- Degree: `very`, `quite`, `rather`, `too`, `so`, `extremely`, `incredibly`

**Examples**:
```
"happy"           → [ADJ]
"very happy"      → [ADV, ADJ]
"quite sad"       → [ADV, ADJ]
"extremely fast"  → [ADV, ADJ]
```

#### Adverbial Phrase (ADVP)

**Structure**: `ADV+`

Currently implemented as single adverbs. Future versions may support:
- `very quickly` (degree + manner)
- `right here` (directional + locative)

**Examples**:
```
"quickly"     → [ADV]
"very well"   → [ADV, ADV] (not yet supported)
```

#### Relative Clause (RC)

**Structure**: `RELATIVIZER CLAUSE`

**Relativizers**:
- Relative pronouns: `who`, `whom`, `whose`, `which`, `that`
- Relative adverbs: `where`, `when`, `why`

**Clause Patterns**:
1. **Relativizer as subject**: `REL_PRON VP`
   - `"that sits"` → `[that, [VP: sits]]`

2. **Relativizer as object**: `REL_PRON NP VP`
   - `"that I see"` → `[that, [NP: I] [VP: see]]`

**Examples**:
```
"that sits"              → [REL_PRON, VP("sits")]
"who I know"             → [REL_PRON, NP("I"), VP("know")]
"which is on the table"  → [REL_PRON, VP("is on the table")]
"where we met"           → [REL_ADV, NP("we"), VP("met")]
```

## Dependency Relations

Nasty uses Universal Dependencies relation taxonomy.

### Core Arguments

| Relation | Description | Example | Head → Dependent |
|----------|-------------|---------|------------------|
| `nsubj` | Nominal subject | "The cat sat" | sat → cat |
| `obj` | Direct object | "saw the cat" | saw → cat |
| `iobj` | Indirect object | "gave her the book" | gave → her |
| `csubj` | Clausal subject | "That he left is sad" | sad → left |
| `ccomp` | Clausal complement | "He said that she left" | said → left |
| `xcomp` | Open clausal complement | "She wants to go" | wants → go |

### Non-Core Dependents

| Relation | Description | Example | Head → Dependent |
|----------|-------------|---------|------------------|
| `obl` | Oblique nominal | "sat on the mat" | sat → mat |
| `advmod` | Adverbial modifier | "runs quickly" | runs → quickly |
| `advcl` | Adverbial clause | "left because tired" | left → tired |
| `aux` | Auxiliary | "is running" | running → is |
| `cop` | Copula | "is happy" | happy → is |
| `mark` | Marker (subordinator) | "because it rained" | rained → because |

### Nominal Dependents

| Relation | Description | Example | Head → Dependent |
|----------|-------------|---------|------------------|
| `nmod` | Nominal modifier | "cat on mat" (PP to noun) | cat → mat |
| `appos` | Appositional modifier | "John, my friend" | John → friend |
| `nummod` | Numeric modifier | "three cats" | cats → three |
| `acl` | Adnominal clause | "cat that sits" | cat → sits |
| `amod` | Adjectival modifier | "big cat" | cat → big |
| `det` | Determiner | "the cat" | cat → the |
| `case` | Case marking (preposition) | "on the mat" | mat → on |
| `clf` | Classifier | "three cups of tea" | cups → of |

### Coordination

| Relation | Description | Example | Head → Dependent |
|----------|-------------|---------|------------------|
| `conj` | Conjunct | "cat and dog" | cat → dog |
| `cc` | Coordinating conjunction | "cat and dog" | cat → and |

### MWE and Other

| Relation | Description | Example | Head → Dependent |
|----------|-------------|---------|------------------|
| `fixed` | Fixed multiword expression | "as well as" | as → well, as → as |
| `flat` | Flat multiword expression | "New York" | New → York |
| `compound` | Compound | "ice cream" | ice → cream |
| `list` | List | "1, 2, 3" | 1 → 2, 1 → 3 |
| `parataxis` | Parataxis | "Go ahead, make my day" | Go → make |
| `punct` | Punctuation | "The cat sat." | sat → . |

### Special

| Relation | Description | Example | Head → Dependent |
|----------|-------------|---------|------------------|
| `root` | Root of sentence | "The cat sat." | ROOT → sat |
| `dep` | Unspecified dependency | (fallback) | head → dep |

### Dependency Extraction Rules

From phrase structures to dependencies:

#### From NP
```
NP(determiner=D, head=H, modifiers=[M1, M2], post_modifiers=[PP])
→ det(H, D)
  amod(H, M1)
  amod(H, M2)
  [dependencies from PP with H as governor]
```

#### From VP
```
VP(auxiliaries=[A1, A2], head=V, complements=[NP, PP, ADVP])
→ aux(V, A1)
  aux(V, A2)
  obj(V, NP.head)
  [dependencies from NP]
  [dependencies from PP with V as governor]
  advmod(V, ADVP.head)
```

#### From PP
```
PP(head=P, object=NP)
→ case(NP.head, P)
  [with governor G:]
    obl(G, NP.head)    # if G is verb
    nmod(G, NP.head)   # if G is noun
  [dependencies from NP]
```

#### From Clause
```
Clause(subject=NP_subj, predicate=VP, subordinator=S)
→ nsubj(VP.head, NP_subj.head)
  [dependencies from NP_subj]
  [dependencies from VP]
  mark(VP.head, S)  # if subordinator present
```

#### From Relative Clause
```
RelativeClause(relativizer=R, clause=C, attached_to=N)
→ mark(C.predicate.head, R)
  acl(N, C.predicate.head)
  [dependencies from C]
```

## Morphological Features

Nasty tracks morphological features for each token based on Universal Features.

### Verb Features

| Feature | Values | Description | Examples |
|---------|--------|-------------|----------|
| `Tense` | `Past`, `Present`, `Future` | Tense of verb | walked (Past), walks (Present) |
| `Aspect` | `Progressive`, `Perfect` | Aspect of verb | running (Progressive), eaten (Perfect) |
| `Mood` | `Indicative`, `Imperative`, `Subjunctive` | Mood | runs (Ind), run! (Imp) |
| `Voice` | `Active`, `Passive` | Voice | saw (Active), was seen (Passive) |
| `Person` | `1`, `2`, `3` | Grammatical person | I walk (1), you walk (2), he walks (3) |
| `Number` | `Singular`, `Plural` | Number agreement | he walks (Sg), they walk (Pl) |
| `VerbForm` | `Finite`, `Infinitive`, `Gerund`, `Participle` | Form of verb | walks (Fin), to walk (Inf), walking (Ger), walked (Part) |

**Implementation** (in code):
```elixir
%{
  tense: :past | :present | :future,
  aspect: :progressive | :perfect,
  person: 1 | 2 | 3,
  number: :singular | :plural
}
```

### Noun Features

| Feature | Values | Description | Examples |
|---------|--------|-------------|----------|
| `Number` | `Singular`, `Plural` | Grammatical number | cat (Sg), cats (Pl) |
| `Case` | `Nominative`, `Accusative`, `Genitive` | Case (mainly for pronouns) | he (Nom), him (Acc), his (Gen) |
| `Person` | `1`, `2`, `3` | Person (for pronouns) | I (1), you (2), he (3) |
| `Gender` | `Masculine`, `Feminine`, `Neuter` | Gender (mainly for pronouns) | he (Masc), she (Fem), it (Neut) |
| `Poss` | `Yes` | Possessive | my, your, his, her |

**Implementation**:
```elixir
%{number: :singular | :plural}
```

### Adjective Features

| Feature | Values | Description | Examples |
|---------|--------|-------------|----------|
| `Degree` | `Positive`, `Comparative`, `Superlative` | Degree of comparison | fast (Pos), faster (Comp), fastest (Sup) |

**Implementation**:
```elixir
%{degree: :positive | :comparative | :superlative}
```

### Morphological Rules

#### Verb Inflection

**Regular Verbs**:
```
Base form:     walk
3rd sg present: walk + s → walks
Past:          walk + ed → walked
Progressive:   walk + ing → walking
Past participle: walk + ed → walked
```

**Irregular Verbs** (dictionary lookup):
```
go → went (past), gone (past participle), going (progressive)
be → am/is/are (present), was/were (past), been (past participle)
have → has (3sg present), had (past)
```

#### Noun Inflection

**Regular Plurals**:
```
cat → cats
box → boxes (after s/x/z/ch/sh)
fly → flies (y → ies after consonant)
```

**Irregular Plurals** (dictionary lookup):
```
child → children
man → men
woman → women
tooth → teeth
mouse → mice
```

#### Adjective Inflection

**Regular Comparison**:
```
fast → faster → fastest
big → bigger → biggest (consonant doubling)
happy → happier → happiest (y → i)
```

**Irregular Comparison** (dictionary lookup):
```
good → better → best
bad → worse → worst
far → farther/further → farthest/furthest
```

## Sentence Types

### By Function

| Type | Description | Punctuation | Example |
|------|-------------|-------------|---------|
| Declarative | Makes a statement | `.` | "The cat sat on the mat." |
| Interrogative | Asks a question | `?` | "Where is the cat?" |
| Exclamative | Expresses strong emotion | `!` | "What a beautiful cat!" |
| Imperative | Gives a command | `.` or `!` | "Sit!" |

**Function Inference**:
- `.` → Declarative
- `?` → Interrogative
- `!` → Exclamative (or Imperative if no subject)

### By Structure

| Type | Description | Pattern | Example |
|------|-------------|---------|---------|
| Simple | One independent clause | `S → NP VP` | "The cat sat." |
| Compound | Multiple independent clauses | `S → CLAUSE CCONJ CLAUSE` | "The cat sat and the dog ran." |
| Complex | Independent + subordinate clause(s) | `S → MAIN_CLAUSE SUBORD_CLAUSE` | "The cat sat because it was tired." |
| Compound-Complex | Multiple independent + subordinate | Combined | "The cat sat and the dog ran because they were tired." |
| Fragment | Incomplete sentence | Various | "Because it was tired." |

**Structure Determination**:
- Simple: 1 independent clause, 0 subordinate clauses
- Compound: 2+ independent clauses, 0 subordinate clauses
- Complex: 1 independent clause, 1+ subordinate clauses
- Compound-Complex: 2+ independent clauses, 1+ subordinate clauses
- Fragment: 0 independent clauses (only subordinate)

### Clause Types

| Type | Description | Marker | Example |
|------|-------------|--------|---------|
| Independent | Can stand alone | None | "The cat sat" |
| Subordinate | Cannot stand alone | SCONJ | "because it was tired" |
| Relative | Modifies a noun | REL_PRON/ADV | "that sits on the mat" |

## Lexical Categories

### Closed-Class Word Lists

These are finite sets of words that rarely change.

#### Determiners (60+ words)

**Articles**:
```
the, a, an
```

**Demonstratives**:
```
this, that, these, those
```

**Possessives**:
```
my, your, his, her, its, our, their, whose
```

**Quantifiers**:
```
some, any, no, every, each, either, neither
much, many, more, most, less, least
few, several, all, both, half
```

#### Pronouns (50+ words)

**Personal (Subject)**:
```
I, you, he, she, it, we, they
```

**Personal (Object)**:
```
me, you, him, her, it, us, them
```

**Possessive**:
```
mine, yours, his, hers, its, ours, theirs
```

**Reflexive**:
```
myself, yourself, himself, herself, itself,
ourselves, yourselves, themselves
```

**Interrogative**:
```
who, whom, whose, which, what
```

**Demonstrative**:
```
this, that, these, those
```

**Indefinite**:
```
someone, somebody, something
anyone, anybody, anything
everyone, everybody, everything
no one, nobody, nothing
```

#### Prepositions (50+ words)

**Common Prepositions**:
```
in, on, at, by, for, with, from, to, of, about
above, across, after, against, along, among, around
before, behind, below, beneath, beside, between, beyond
down, during, except, inside, into, like, near
off, over, past, since, through, throughout, till
toward, under, underneath, until, up, upon, within, without
```

#### Conjunctions

**Coordinating Conjunctions (7 words)**:
```
and, or, but, nor, yet, so, for
```

**Subordinating Conjunctions (30+ words)**:
```
after, although, as, because, before, if, once, since
than, that, though, till, unless, until, when, whenever
where, wherever, whether, while
```

#### Auxiliaries (20+ words)

**Be**:
```
am, is, are, was, were, be, been, being
```

**Have**:
```
have, has, had, having
```

**Do**:
```
do, does, did, doing
```

**Modals**:
```
will, would, shall, should
can, could, may, might, must, ought
```

#### Adverbs (100+ words)

**Manner**:
```
well, badly, carefully, quickly, slowly, easily
```

**Frequency**:
```
always, never, often, sometimes, usually, rarely, seldom
```

**Time**:
```
now, then, soon, later, already, yet, still, just
```

**Place**:
```
here, there, everywhere, nowhere, anywhere, somewhere
```

**Degree**:
```
very, really, quite, rather, too, so, enough
```

**Interrogative**:
```
how, why, when, where
```

**Conjunctive**:
```
however, therefore, moreover, furthermore,
nevertheless, nonetheless, besides, otherwise
```

#### Particles (10+ words)

**Common Particles**:
```
to (infinitive marker)
up, down, out, off, in, on, away, back
```

#### Interjections

**Common Interjections**:
```
ah, oh, wow, hey, hi, hello, goodbye, bye
yes, no, yeah, nope
thanks, please, sorry
ouch, oops, ugh, hmm, huh
```

### Common Verbs (Top 150)

**High-Frequency Verbs**:
```
be, have, do, say, go, get, make, know, think, take
see, come, want, use, find, give, tell, work, call, try
ask, need, feel, become, leave, put, mean, keep, let, begin
seem, help, show, hear, play, run, move, like, live, believe
bring, happen, write, sit, stand, lose, pay, meet, include, continue
set, learn, change, lead, understand, watch, follow, stop, create, speak
read, spend, grow, open, walk, win, teach, offer, remember, consider
appear, buy, serve, die, send, build, stay, fall, cut, reach
kill, raise, pass, sell, decide, return, explain, hope, develop, carry
break, receive, agree, support, hit, produce, eat, cover, catch, draw
```

### Common Adjectives (Top 100)

**High-Frequency Adjectives**:
```
good, bad, big, small, large, little, new, old, young, long
short, high, low, great, right, left, different, same, next, last
early, late, public, important, able, free, real, sure, certain, wrong
ready, clear, white, black, red, blue, green, hot, cold, open
happy, sad, easy, hard, strong, weak, full, empty, rich, poor
heavy, light, fast, slow, clean, dirty, safe, dangerous, cheap, expensive
quiet, loud, wide, narrow, deep, shallow, thick, thin, bright, dark
soft, hard, smooth, rough, wet, dry, simple, complex, common, rare
perfect, terrible, beautiful, ugly, wonderful, awful, excellent, fine, nice, special
```

### Common Nouns (Top 100)

**High-Frequency Nouns**:
```
time, person, year, way, day, thing, man, world, life, hand
part, child, eye, woman, place, work, week, case, point, government
company, number, group, problem, fact, people, water, room, money, story
book, word, question, school, state, family, student, system, program, teacher
house, home, office, door, car, street, city, country, name, area
idea, body, face, food, job, night, power, end, side, week
mother, father, friend, girl, boy, business, service, health, law, level
hour, game, line, member, mind, minute, music, party, result, death
```

## Ambiguity and Disambiguation

### Common Ambiguities

1. **POS Ambiguity**:
   - `book` → NOUN ("I read a book") or VERB ("Book a flight")
   - `fast` → ADJ ("He is fast") or ADV ("He runs fast")
   - `that` → DET ("that book"), PRON ("I see that"), or SCONJ ("I know that he left")

2. **PP Attachment**:
   - `"I saw the man with a telescope"`
     - Attach to VP: I used a telescope to see the man
     - Attach to NP: The man had a telescope

3. **Coordination Scope**:
   - `"old men and women"`
     - [old men] and [women]
     - [old [men and women]]

### Disambiguation Strategies

1. **Lexical Lookup Priority**: Check closed-class lists first
2. **Morphological Cues**: Use suffixes to infer POS
3. **Contextual Rules**: Use local context (e.g., word after DET is likely NOUN)
4. **Statistical Models**: Use HMM or neural models for better accuracy
5. **Selectional Preferences**: Verbs prefer certain argument types
6. **Semantic Plausibility**: More plausible interpretations preferred

## Grammar Extensions (Future)

Planned extensions to the grammar:

1. **Comparative Constructions**: "John is taller than Mary"
2. **Passive Voice**: "The cat was seen by Mary"
3. **Wh-Questions**: "What did you see?"
4. **Ellipsis**: "John likes apples and Mary [likes] oranges"
5. **Coordination**: Better handling of coordinated phrases
6. **Negation**: Explicit negation marking
7. **Modality**: Modal auxiliary semantics
8. **Aspect**: Progressive, perfect aspect marking

## References

- **Universal Dependencies**: https://universaldependencies.org/
- **Penn Treebank**: Marcus et al. (1993)
- **Cambridge Grammar of English**: Huddleston & Pullum (2002)
- **English Grammar**: Quirk et al. (1985)
- **Universal Features**: https://universaldependencies.org/u/feat/
- **UD English-EWT Treebank**: https://github.com/UniversalDependencies/UD_English-EWT
