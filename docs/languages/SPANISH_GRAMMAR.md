# Spanish Grammar Specification

Formal specification of Spanish grammar for the Nasty NLP library.

## Overview

Spanish is a Romance language with:
- Subject-verb-object (SVO) word order with flexibility (VSO, VOS possible)
- Pro-drop (null subjects allowed)
- Rich verb morphology with gender and number agreement
- Post-nominal adjectives (with some exceptions)
- Two copular verbs (ser/estar)
- Clitic pronouns

## Lexical Categories

### Parts of Speech (Universal Dependencies Tagset)

#### Nouns (NOUN)
Spanish nouns have grammatical gender (masculine/feminine) and number (singular/plural).

```
casa (house, feminine)
libro (book, masculine)
casas (houses, plural)
```

Gender markers:
- Masculine: typically ends in -o
- Feminine: typically ends in -a
- Exceptions: el día (masculine), la mano (feminine)

#### Verbs (VERB)
Spanish verbs conjugate for:
- Person: 1st, 2nd, 3rd
- Number: singular, plural
- Tense: present, preterite, imperfect, future, conditional
- Mood: indicative, subjunctive, imperative
- Aspect: simple, progressive, perfect

Three conjugation classes: -ar, -er, -ir

Present tense patterns:
```
-ar: hablo, hablas, habla, hablamos, habláis, hablan
-er: como, comes, come, comemos, coméis, comen
-ir: vivo, vives, vive, vivimos, vivís, viven
```

Auxiliary verbs:
- haber (perfective aspect)
- ser (passive voice, copula)
- estar (progressive aspect, copula)

#### Adjectives (ADJ)
Adjectives agree in gender and number with nouns. Most appear post-nominally:

```
casa grande (big house)
libros interesantes (interesting books)
```

Pre-nominal adjectives (limited set):
```
buen libro (good book)
mucha gente (many people)
```

#### Determiners (DET)
Articles:
- Definite: el, la, los, las
- Indefinite: un, una, unos, unas

Demonstratives: este, ese, aquel (+ gender/number variants)

Possessives: mi, tu, su, nuestro, vuestro (+ number variants)

#### Pronouns (PRON)
Subject pronouns (often omitted due to pro-drop):
- yo, tú, él/ella/usted
- nosotros/nosotras, vosotros/vosotras, ellos/ellas/ustedes

Object pronouns (clitics):
- Direct object: me, te, lo/la, nos, os, los/las
- Indirect object: me, te, le, nos, os, les
- Reflexive: se

#### Adpositions (ADP)
Prepositions: a, de, en, con, por, para, sin, sobre, entre, desde, hasta, etc.

No postpositions in Spanish.

#### Adverbs (ADV)
Manner: -mente suffix (rápidamente, lentamente)
Place: aquí, allí, cerca, lejos
Time: ahora, ayer, mañana, siempre, nunca
Degree: muy, más, menos, tan, bastante

#### Conjunctions
Coordinating (CCONJ): y, o, pero, ni, sino
Subordinating (SCONJ): que, porque, cuando, si, aunque, mientras

## Morphology

### Verb Morphology

#### Present Tense (-ar verbs: hablar)
```
hablo (I speak)
hablas (you speak, informal)
habla (he/she speaks, you speak formal)
hablamos (we speak)
habláis (you all speak, Spain)
hablan (they/you all speak)
```

#### Preterite Tense (-ar verbs: hablar)
```
hablé (I spoke)
hablaste (you spoke)
habló (he/she spoke)
hablamos (we spoke)
hablasteis (you all spoke)
hablaron (they spoke)
```

#### Imperfect Tense
```
-ar: hablaba, hablabas, hablaba, hablábamos, hablabais, hablaban
-er/-ir: comía, comías, comía, comíamos, comíais, comían
```

#### Future Tense
```
hablaré, hablarás, hablará, hablaremos, hablaréis, hablarán
```

#### Gerund (Progressive)
```
-ar: hablando
-er: comiendo
-ir: viviendo
```

#### Past Participle (Perfect)
```
-ar: hablado
-er: comido
-ir: vivido
```

### Noun Morphology

Plural formation:
- Add -s if ends in vowel: casa → casas
- Add -es if ends in consonant: ciudad → ciudades
- No change if ends in -s (non-final stress): crisis → crisis

Gender agreement:
- Adjectives match noun gender: gato blanco, gata blanca

## Phrase Structure

### Noun Phrase (NP)
```
NP → (Det) (Quantifier) N (AP) (PP) (RelClause)
```

Examples:
```
el gato             (Det N)
el gato negro       (Det N AP)
el gato de María    (Det N PP)
muchos libros       (Quant N)
```

Key features:
- Determiners precede nouns
- Most adjectives follow nouns
- Prepositional phrases follow nouns
- Relative clauses follow nouns

### Verb Phrase (VP)
```
VP → (Aux) V (Clitic) (NP) (PP) (AdvP)
```

Examples:
```
come               (V)
está comiendo      (Aux V-gerund)
ha comido          (Aux V-participle)
lo vio             (Clitic V)
come una manzana   (V NP)
vive en Madrid     (V PP)
```

Clitic placement:
- Proclitic (before verb): lo veo
- Enclitic (attached to infinitive, gerund, imperative): verlo, viéndolo, dámelo

### Prepositional Phrase (PP)
```
PP → P NP
```

Examples:
```
en la casa
de Madrid
con mis amigos
para ti
```

Common prepositions:
- Location: en, a, de, desde, hasta
- Instrumental: con
- Benefactive: para
- Causative: por

### Adjective Phrase (AP)
```
AP → (AdvP) A
```

Examples:
```
muy grande (very big)
bastante interesante (quite interesting)
```

### Adverbial Phrase (AdvP)
```
AdvP → (AdvP) Adv
```

Examples:
```
muy rápidamente
bastante bien
```

## Sentence Structure

### Basic Sentence
```
S → NP VP
S → VP          (pro-drop: null subject)
```

Examples:
```
El gato duerme.           (NP VP)
Duerme.                   (VP - pro-drop)
María lee un libro.       (NP VP NP)
```

### Clause Structure
```
Clause → (NP) VP
```

Pro-drop examples:
```
Voy al parque.            (go-1sg to-the park: "I go to the park")
Comimos ayer.             (ate-1pl yesterday: "We ate yesterday")
```

### Coordination
```
S → S Conj S
NP → NP Conj NP
VP → VP Conj VP
```

Conjunctions:
- y (and), e (before i/hi)
- o (or), u (before o/ho)
- pero, mas (but)
- sino (but rather)
- ni (nor)

Examples:
```
Juan y María vinieron.
Come manzanas o naranjas.
No vino Juan sino Pedro.
```

### Subordination
```
S → S SCONJ S
```

Subordinating conjunctions:
- que (that)
- porque (because)
- cuando (when)
- si (if)
- aunque (although)
- mientras (while)

Examples:
```
Dijo que vendría.              (He said that he would come)
Vino porque lo llamé.          (He came because I called him)
Lo haré cuando pueda.          (I'll do it when I can)
```

### Relative Clauses
```
NP → NP RelClause
RelClause → RelPron Clause
```

Relative pronouns:
- que (that/which/who)
- quien/quienes (who)
- cual/cuales (which)
- cuyo/cuya/cuyos/cuyas (whose)
- donde (where)
- cuando (when)

Examples:
```
El libro que leí es bueno.          (The book that I read is good)
La mujer con quien hablé es mi tía.  (The woman with whom I talked is my aunt)
```

## Question Formation

### Wh-Questions
Question words (always with accent):
- ¿Qué? (what)
- ¿Quién/Quiénes? (who)
- ¿Dónde? (where)
- ¿Cuándo? (when)
- ¿Por qué? (why)
- ¿Cómo? (how)
- ¿Cuál/Cuáles? (which)
- ¿Cuánto/Cuánta/Cuántos/Cuántas? (how much/many)

Syntax:
```
¿Wh-word + V + (NP) + ...?
```

Examples:
```
¿Qué comes?                (What do you eat?)
¿Quién vino?               (Who came?)
¿Dónde vives?              (Where do you live?)
¿Cuándo llegaste?          (When did you arrive?)
```

### Yes/No Questions
Intonation-based with optional inversion:
```
¿Comes manzanas?           (Do you eat apples?)
¿Vino Juan?                (Did Juan come?)
```

Punctuation: ¿ ... ?

## Dependency Relations (Universal Dependencies)

### Core Arguments
- **nsubj**: nominal subject
  - El gato duerme. (gato → duerme)
- **obj**: direct object
  - Come una manzana. (manzana → come)
- **iobj**: indirect object
  - Di un libro a Juan. (Juan → di)

### Non-core Dependents
- **obl**: oblique nominal
  - Vive en Madrid. (Madrid → vive)
- **advmod**: adverbial modifier
  - Come rápidamente. (rápidamente → come)
- **aux**: auxiliary
  - Ha comido. (ha → comido)

### Nominal Dependents
- **det**: determiner
  - El gato (el → gato)
- **amod**: adjectival modifier
  - Gato negro (negro → gato)
- **nmod**: nominal modifier
  - Casa de María (María → casa)
- **case**: case marking (preposition)
  - En la casa (en → casa)

### Clausal Dependents
- **ccomp**: clausal complement
  - Dijo que vendría. (vendría → dijo)
- **acl**: adnominal clause
  - El libro que leí (leí → libro)
- **advcl**: adverbial clause
  - Vino porque llamé. (llamé → vino)

### Coordination
- **conj**: conjunct
  - Juan y María (María → Juan)
- **cc**: coordinating conjunction
  - Juan y María (y → María)

### Special
- **mark**: subordinating conjunction
  - Dijo que vendría. (que → vendría)
- **expl:pv**: reflexive clitic
  - Se sentó. (se → sentó)

## Semantic Roles

Based on PropBank/FrameNet conventions:

### Core Arguments
- **ARG0**: Agent (typically subject)
  - Juan comió la manzana. (Juan = ARG0)
- **ARG1**: Patient/Theme (typically object)
  - Juan comió la manzana. (manzana = ARG1)
- **ARG2**: Instrument, Benefactive, Attribute
  - Cortó el pan con un cuchillo. (cuchillo = ARG2)
- **ARG3**: Starting point, Benefactive
  - Dio un libro a María. (María = ARG3)

### Adjunct Arguments
- **ARGM-LOC**: Location
  - Vive en Madrid. (en Madrid = ARGM-LOC)
- **ARGM-TMP**: Time
  - Llegó ayer. (ayer = ARGM-TMP)
- **ARGM-MNR**: Manner
  - Come rápidamente. (rápidamente = ARGM-MNR)
- **ARGM-CAU**: Cause
  - Vino porque lo llamé. (porque lo llamé = ARGM-CAU)
- **ARGM-PRP**: Purpose
  - Estudia para aprender. (para aprender = ARGM-PRP)

## Coreference

Spanish coreference patterns:

### Pronoun-Antecedent
```
Juan llegó. Él estaba cansado.
(Juan ← él)
```

### Null Subject (Pro-drop)
```
María llegó. Ø Estaba cansada.
(María ← Ø)
```

### Clitic-Antecedent
```
Vi a Juan. Lo saludé.
(Juan ← lo)
```

### Definite NP-Antecedent
```
Compré un libro. El libro es interesante.
(un libro ← el libro)
```

Agreement constraints:
- Gender: masculine/feminine
- Number: singular/plural
- Person: 1st/2nd/3rd

## Special Constructions

### Reflexives
Reflexive clitic se + verb:
```
Se lava. (He washes himself)
Se sienta. (He sits down)
```

### Passive
Ser + past participle:
```
La casa fue construida. (The house was built)
```

Reflexive passive (more common):
```
Se construyó la casa. (The house was built)
```

### Impersonal Se
```
Se habla español. (Spanish is spoken / One speaks Spanish)
```

### Periphrastic Future
Ir a + infinitive:
```
Voy a comer. (I'm going to eat)
```

### Progressive
Estar + gerund:
```
Estoy comiendo. (I'm eating)
```

### Perfect
Haber + past participle:
```
He comido. (I have eaten)
```

## References

- Real Academia Española (RAE) - Nueva gramática de la lengua española
- Universal Dependencies - Spanish treebanks
- Butt & Benjamin - A New Reference Grammar of Modern Spanish
- Bosque & Demonte - Gramática descriptiva de la lengua española
