# Multilingual Pipeline Example
#
# This example demonstrates processing the same text in multiple languages:
# - English, Spanish, and Catalan side-by-side
# - Compare tokenization, POS tagging, and parsing
# - Show language-specific features
# - Cross-language translation comparison
#
# Run with: mix run examples/multilingual_pipeline.exs

alias Nasty.Language.{English, Spanish, Catalan}
alias Nasty.Translation.Translator

IO.puts("\n========================================")
IO.puts("Multilingual Pipeline Comparison")
IO.puts("========================================\n")

# Test text (semantically equivalent in each language)
test_texts = %{
  en: "The big cat sleeps in the house.",
  es: "El gato grande duerme en la casa.",
  ca: "El gat gran dorm a la casa."
}

IO.puts("Processing the same semantic content in three languages:")
IO.puts("English: #{test_texts.en}")
IO.puts("Spanish: #{test_texts.es}")
IO.puts("Catalan: #{test_texts.ca}\n")

# Step 1: Tokenization Comparison
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("STEP 1: Tokenization")
IO.puts("=" <> String.duplicate("=", 60))

{:ok, tokens_en} = English.tokenize(test_texts.en)
{:ok, tokens_es} = Spanish.tokenize(test_texts.es)
{:ok, tokens_ca} = Catalan.tokenize(test_texts.ca)

IO.puts("\nToken Count:")
IO.puts("  English: #{length(tokens_en)} tokens")
IO.puts("  Spanish: #{length(tokens_es)} tokens")
IO.puts("  Catalan: #{length(tokens_ca)} tokens")

IO.puts("\nTokens Side-by-Side:")
max_len = max(length(tokens_en), max(length(tokens_es), length(tokens_ca)))

IO.puts(String.pad_trailing("English", 25) <> String.pad_trailing("Spanish", 25) <> "Catalan")
IO.puts(String.duplicate("-", 75))

for i <- 0..(max_len - 1) do
  en_token = if i < length(tokens_en), do: Enum.at(tokens_en, i).text, else: ""
  es_token = if i < length(tokens_es), do: Enum.at(tokens_es, i).text, else: ""
  ca_token = if i < length(tokens_ca), do: Enum.at(tokens_ca, i).text, else: ""
  
  IO.puts(
    String.pad_trailing(en_token, 25) <>
    String.pad_trailing(es_token, 25) <>
    ca_token
  )
end

# Step 2: POS Tagging Comparison
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 2: Part-of-Speech Tagging")
IO.puts(String.duplicate("=", 60))

{:ok, tagged_en} = English.tag_pos(tokens_en)
{:ok, tagged_es} = Spanish.tag_pos(tokens_es)
{:ok, tagged_ca} = Catalan.tag_pos(tokens_ca)

IO.puts("\nPOS Tags Side-by-Side:")
IO.puts(String.pad_trailing("English", 25) <> String.pad_trailing("Spanish", 25) <> "Catalan")
IO.puts(String.duplicate("-", 75))

# Align by semantic content
alignments = [
  {0, 0, 0},  # The/El/El
  {1, 1, 1},  # big/grande/gran
  {2, 2, 2},  # cat/gato/gat
  {3, 3, 3},  # sleeps/duerme/dorm
  {4, 4, 4},  # in/en/a
  {5, 5, 5},  # the/la/la
  {6, 6, 6},  # house/casa/casa
  {7, 7, 7}   # ./././
]

Enum.each(alignments, fn {en_idx, es_idx, ca_idx} ->
  en_tag = if en_idx < length(tagged_en) do
    t = Enum.at(tagged_en, en_idx)
    "#{t.text} (#{t.pos_tag})"
  else
    ""
  end
  
  es_tag = if es_idx < length(tagged_es) do
    t = Enum.at(tagged_es, es_idx)
    "#{t.text} (#{t.pos_tag})"
  else
    ""
  end
  
  ca_tag = if ca_idx < length(tagged_ca) do
    t = Enum.at(tagged_ca, ca_idx)
    "#{t.text} (#{t.pos_tag})"
  else
    ""
  end
  
  IO.puts(
    String.pad_trailing(en_tag, 25) <>
    String.pad_trailing(es_tag, 25) <>
    ca_tag
  )
end)

# Step 3: Morphological Features
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 3: Morphological Features")
IO.puts(String.duplicate("=", 60))

IO.puts("\nKey Differences:")
IO.puts("\n1. Determiners:")
IO.puts("   EN: 'the' (gender-neutral)")
IO.puts("   ES: 'el/la' (masculine/feminine)")
IO.puts("   CA: 'el/la' (masculine/feminine)")

IO.puts("\n2. Adjective Position:")
IO.puts("   EN: 'big cat' (adjective before noun)")
IO.puts("   ES: 'gato grande' (adjective after noun)")
IO.puts("   CA: 'gat gran' (adjective after noun)")

IO.puts("\n3. Prepositions:")
IO.puts("   EN: 'in' (location)")
IO.puts("   ES: 'en' (location)")
IO.puts("   CA: 'a' (location - different preposition)")

# Step 4: Parsing Comparison
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 4: Syntactic Parsing")
IO.puts(String.duplicate("=", 60))

{:ok, doc_en} = English.parse(tagged_en)
{:ok, doc_es} = Spanish.parse(tagged_es)
{:ok, doc_ca} = Catalan.parse(tagged_ca)

# Extract main clause from each
get_main_clause = fn doc ->
  doc.paragraphs
  |> List.first()
  |> Map.get(:sentences)
  |> List.first()
  |> Map.get(:main_clause)
end

clause_en = get_main_clause.(doc_en)
clause_es = get_main_clause.(doc_es)
clause_ca = get_main_clause.(doc_ca)

extract_subject_text = fn clause ->
  if clause && clause.subject do
    case clause.subject do
      %Nasty.AST.NounPhrase{} = np ->
        det = if np.determiner, do: np.determiner.text <> " ", else: ""
        mods = Enum.map(np.modifiers, & &1.text) |> Enum.join(" ")
        mods_str = if mods != "", do: mods <> " ", else: ""
        "#{det}#{mods_str}#{np.head.text}"
      _ -> ""
    end
  else
    ""
  end
end

extract_verb_text = fn clause ->
  if clause && clause.predicate do
    vp = clause.predicate
    aux = Enum.map(vp.auxiliaries, & &1.text) |> Enum.join(" ")
    aux_str = if aux != "", do: aux <> " ", else: ""
    "#{aux_str}#{vp.head.text}"
  else
    ""
  end
end

IO.puts("\nSubject Extraction:")
IO.puts("  English: #{extract_subject_text.(clause_en)}")
IO.puts("  Spanish: #{extract_subject_text.(clause_es)}")
IO.puts("  Catalan: #{extract_subject_text.(clause_ca)}")

IO.puts("\nVerb Extraction:")
IO.puts("  English: #{extract_verb_text.(clause_en)}")
IO.puts("  Spanish: #{extract_verb_text.(clause_es)}")
IO.puts("  Catalan: #{extract_verb_text.(clause_ca)}")

# Step 5: Translation Matrix
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 5: Cross-Language Translation Matrix")
IO.puts(String.duplicate("=", 60))

IO.puts("\nTranslation Matrix (Original → Translated):\n")

# English → Spanish
{:ok, en_to_es} = Translator.translate(doc_en, :es)
{:ok, en_to_es_text} = Nasty.Rendering.Text.render(en_to_es)

# English → Catalan
{:ok, en_to_ca} = Translator.translate(doc_en, :ca)
{:ok, en_to_ca_text} = Nasty.Rendering.Text.render(en_to_ca)

# Spanish → English
{:ok, es_to_en} = Translator.translate(doc_es, :en)
{:ok, es_to_en_text} = Nasty.Rendering.Text.render(es_to_en)

# Spanish → Catalan (via English)
{:ok, es_to_ca_temp} = Translator.translate(doc_es, :en)
{:ok, es_to_ca} = Translator.translate(es_to_ca_temp, :ca)
{:ok, es_to_ca_text} = Nasty.Rendering.Text.render(es_to_ca)

# Catalan → English
{:ok, ca_to_en} = Translator.translate(doc_ca, :en)
{:ok, ca_to_en_text} = Nasty.Rendering.Text.render(ca_to_en)

# Catalan → Spanish (via English)
{:ok, ca_to_es_temp} = Translator.translate(doc_ca, :en)
{:ok, ca_to_es} = Translator.translate(ca_to_es_temp, :es)
{:ok, ca_to_es_text} = Nasty.Rendering.Text.render(ca_to_es)

IO.puts("FROM ENGLISH:")
IO.puts("  → Spanish: #{en_to_es_text}")
IO.puts("  → Catalan: #{en_to_ca_text}")

IO.puts("\nFROM SPANISH:")
IO.puts("  → English: #{es_to_en_text}")
IO.puts("  → Catalan: #{es_to_ca_text}")

IO.puts("\nFROM CATALAN:")
IO.puts("  → English: #{ca_to_en_text}")
IO.puts("  → Spanish: #{ca_to_es_text}")

# Step 6: Complex Example
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 6: Complex Sentence Comparison")
IO.puts(String.duplicate("=", 60))

complex_texts = %{
  en: "The young student reads an interesting book in the library.",
  es: "El estudiante joven lee un libro interesante en la biblioteca.",
  ca: "L'estudiant jove llegeix un llibre interessant a la biblioteca."
}

IO.puts("\nComplex Sentences:")
IO.puts("  EN: #{complex_texts.en}")
IO.puts("  ES: #{complex_texts.es}")
IO.puts("  CA: #{complex_texts.ca}")

# Process each
{:ok, complex_tokens_en} = English.tokenize(complex_texts.en)
{:ok, complex_tagged_en} = English.tag_pos(complex_tokens_en)
{:ok, complex_doc_en} = English.parse(complex_tagged_en)

{:ok, complex_tokens_es} = Spanish.tokenize(complex_texts.es)
{:ok, complex_tagged_es} = Spanish.tag_pos(complex_tokens_es)
{:ok, complex_doc_es} = Spanish.parse(complex_tagged_es)

{:ok, complex_tokens_ca} = Catalan.tokenize(complex_texts.ca)
{:ok, complex_tagged_ca} = Catalan.tag_pos(complex_tokens_ca)
{:ok, complex_doc_ca} = Catalan.parse(complex_tagged_ca)

IO.puts("\nParsing Statistics:")
IO.puts("  English: #{length(complex_tokens_en)} tokens")
IO.puts("  Spanish: #{length(complex_tokens_es)} tokens")
IO.puts("  Catalan: #{length(complex_tokens_ca)} tokens")

# Step 7: Language-Specific Features Summary
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 7: Language-Specific Features Summary")
IO.puts(String.duplicate("=", 60))

IO.puts("\nENGLISH Features:")
IO.puts("  • Gender-neutral articles (the)")
IO.puts("  • Adjectives before nouns")
IO.puts("  • SVO word order (Subject-Verb-Object)")
IO.puts("  • No pro-drop (subject required)")
IO.puts("  • Prepositions: in, on, at")

IO.puts("\nSPANISH Features:")
IO.puts("  • Gendered articles (el/la, un/una)")
IO.puts("  • Adjectives typically after nouns")
IO.puts("  • SVO word order (flexible)")
IO.puts("  • Pro-drop (subject optional)")
IO.puts("  • Contractions: del, al")
IO.puts("  • Question marks: ¿?")
IO.puts("  • Exclamation marks: ¡!")

IO.puts("\nCATALAN Features:")
IO.puts("  • Gendered articles (el/la, un/una)")
IO.puts("  • Adjectives after nouns")
IO.puts("  • SVO word order (flexible)")
IO.puts("  • Pro-drop (subject optional)")
IO.puts("  • Interpunct: l·l")
IO.puts("  • Apostrophe contractions: l', d', s'")
IO.puts("  • Article contractions: del, al, pel, cal")
IO.puts("  • 10 diacritics: à, è, é, í, ï, ò, ó, ú, ü, ç")

# Step 8: Performance Comparison
IO.puts("\n\n" <> String.duplicate("=", 60))
IO.puts("STEP 8: Pipeline Performance")
IO.puts(String.duplicate("=", 60))

measure_time = fn lang_module, text ->
  {time, _} = :timer.tc(fn ->
    {:ok, tokens} = lang_module.tokenize(text)
    {:ok, tagged} = lang_module.tag_pos(tokens)
    {:ok, _doc} = lang_module.parse(tagged)
  end)
  time / 1000  # Convert to milliseconds
end

IO.puts("\nProcessing Time (milliseconds):")
time_en = measure_time.(English, complex_texts.en)
time_es = measure_time.(Spanish, complex_texts.es)
time_ca = measure_time.(Catalan, complex_texts.ca)

IO.puts("  English: #{Float.round(time_en, 2)} ms")
IO.puts("  Spanish: #{Float.round(time_es, 2)} ms")
IO.puts("  Catalan: #{Float.round(time_ca, 2)} ms")

IO.puts("\n========================================")
IO.puts("Multilingual Pipeline Complete!")
IO.puts("========================================\n")

IO.puts("Key Insights:")
IO.puts("  • All three languages share SVO base word order")
IO.puts("  • Spanish and Catalan have grammatical gender")
IO.puts("  • Adjective position differs (pre vs post-nominal)")
IO.puts("  • Translation preserves semantic content")
IO.puts("  • AST structure enables language-agnostic processing")
IO.puts("  • Catalan has unique orthographic features (interpunct)")
IO.puts("")
