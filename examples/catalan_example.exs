#!/usr/bin/env elixir

# Catalan Language Processing Example
# 
# This example demonstrates Catalan-specific NLP processing including:
# - Tokenization with Catalan punctuation and diacritics
# - POS tagging with Catalan morphology
# - Phrase and sentence parsing
# - Entity recognition with Catalan lexicons
# - Translation between Catalan and English

Mix.install([
  {:nasty, path: Path.expand("..", __DIR__)}
])

alias Nasty.Language.{Catalan, English}
alias Nasty.Translation.Translator

IO.puts("\n========================================")
IO.puts("Catalan Language Processing Demo")
IO.puts("========================================\n")

# Example 1: Basic Tokenization
IO.puts("1. Tokenization with Catalan-specific features")
IO.puts("-----------------------------------------------")

catalan_text = "L'àguila vola al cel. El gat dorm al sofà."
IO.puts("Input: #{catalan_text}")

{:ok, tokens} = Catalan.tokenize(catalan_text)
IO.puts("\nTokens:")
Enum.each(tokens, fn token ->
  IO.puts("  #{token.text} (#{token.span.start_pos |> elem(0)}:#{token.span.start_pos |> elem(1)})")
end)

# Example 2: POS Tagging
IO.puts("\n2. Part-of-Speech Tagging")
IO.puts("---------------------------")

{:ok, tagged} = Catalan.tag_pos(tokens)
IO.puts("\nTagged tokens:")
Enum.each(tagged, fn token ->
  lemma_str = if token.lemma && token.lemma != token.text, do: " [#{token.lemma}]", else: ""
  IO.puts("  #{token.text}#{lemma_str} → #{token.pos_tag}")
end)

# Example 3: Morphological Analysis
IO.puts("\n3. Morphological Features")
IO.puts("--------------------------")

IO.puts("\nTokens with morphology:")
Enum.each(tagged, fn token ->
  if map_size(token.morphology) > 0 do
    morph_str = Enum.map(token.morphology, fn {k, v} -> "#{k}=#{v}" end) |> Enum.join(", ")
    IO.puts("  #{token.text}: {#{morph_str}}")
  end
end)

# Example 4: Phrase Parsing
IO.puts("\n4. Phrase Structure Parsing")
IO.puts("-----------------------------")

{:ok, document} = Catalan.parse(tagged)

IO.puts("\nParsed structure:")
Enum.each(document.paragraphs, fn paragraph ->
  Enum.each(paragraph.sentences, fn sentence ->
    IO.puts("  Sentence: #{sentence.function}, #{sentence.structure}")
    
    if sentence.main_clause do
      clause = sentence.main_clause
      
      if clause.subject do
        subject_text = extract_phrase_text(clause.subject)
        IO.puts("    Subject: #{subject_text}")
      end
      
      if clause.predicate do
        predicate_text = extract_phrase_text(clause.predicate)
        IO.puts("    Predicate: #{predicate_text}")
      end
    end
  end)
end)

# Example 5: Complex Catalan Sentence
IO.puts("\n5. Complex Sentence Analysis")
IO.puts("-----------------------------")

complex_text = "El professor ensenya català als estudiants a l'escola de Barcelona."
IO.puts("Input: #{complex_text}")

{:ok, tokens_complex} = Catalan.tokenize(complex_text)
{:ok, tagged_complex} = Catalan.tag_pos(tokens_complex)
{:ok, doc_complex} = Catalan.parse(tagged_complex)

IO.puts("\nParsed components:")
sentence = List.first(List.first(doc_complex.paragraphs).sentences)

if sentence.main_clause do
  clause = sentence.main_clause
  
  # Extract noun phrases
  noun_phrases = extract_noun_phrases(clause)
  if length(noun_phrases) > 0 do
    IO.puts("\n  Noun Phrases:")
    Enum.each(noun_phrases, fn np ->
      det = if np.determiner, do: np.determiner.text <> " ", else: ""
      mods = Enum.map(np.modifiers, & &1.text) |> Enum.join(" ")
      mods_str = if mods != "", do: mods <> " ", else: ""
      head = np.head.text
      IO.puts("    - #{det}#{mods_str}#{head}")
    end)
  end
  
  # Extract verb phrase
  if clause.predicate do
    vp = clause.predicate
    aux = Enum.map(vp.auxiliaries, & &1.text) |> Enum.join(" ")
    aux_str = if aux != "", do: aux <> " ", else: ""
    verb = vp.head.text
    IO.puts("\n  Verb Phrase:")
    IO.puts("    - #{aux_str}#{verb}")
  end
end

# Example 6: Catalan Diacritics
IO.puts("\n6. Catalan Diacritics Handling")
IO.puts("--------------------------------")

diacritics_text = "L'ós és molt gran. La plaça té una font."
IO.puts("Input: #{diacritics_text}")

{:ok, tokens_diac} = Catalan.tokenize(diacritics_text)
{:ok, tagged_diac} = Catalan.tag_pos(tokens_diac)

IO.puts("\nWords with diacritics:")
Enum.each(tagged_diac, fn token ->
  if String.match?(token.text, ~r/[àèéíïòóúüç]/) do
    IO.puts("  #{token.text} (#{token.pos_tag})")
  end
end)

# Example 7: Catalan Contractions
IO.puts("\n7. Catalan Contractions")
IO.puts("------------------------")

contractions_text = "L'home va del mercat al restaurant pel carrer."
IO.puts("Input: #{contractions_text}")

{:ok, tokens_contr} = Catalan.tokenize(contractions_text)
{:ok, tagged_contr} = Catalan.tag_pos(tokens_contr)

IO.puts("\nContractions found:")
Enum.each(tagged_contr, fn token ->
  if String.contains?(token.text, "'") or token.text in ["del", "al", "pel", "cal"] do
    IO.puts("  #{token.text} → #{token.pos_tag}")
  end
end)

# Example 8: Translation - Catalan to English
IO.puts("\n8. Translation: Catalan → English")
IO.puts("-----------------------------------")

ca_to_translate = "El gat negre dorm al jardí."
IO.puts("Catalan: #{ca_to_translate}")

{:ok, tokens_ca} = Catalan.tokenize(ca_to_translate)
{:ok, tagged_ca} = Catalan.tag_pos(tokens_ca)
{:ok, doc_ca} = Catalan.parse(tagged_ca)

{:ok, doc_en} = Translator.translate(doc_ca, :en)
{:ok, text_en} = Nasty.Rendering.Text.render(doc_en)

IO.puts("English: #{text_en}")

# Example 9: Translation - English to Catalan
IO.puts("\n9. Translation: English → Catalan")
IO.puts("-----------------------------------")

en_to_translate = "The big house is very beautiful."
IO.puts("English: #{en_to_translate}")

{:ok, tokens_en} = English.tokenize(en_to_translate)
{:ok, tagged_en} = English.tag_pos(tokens_en)
{:ok, doc_en2} = English.parse(tagged_en)

{:ok, doc_ca2} = Translator.translate(doc_en2, :ca)
{:ok, text_ca2} = Nasty.Rendering.Text.render(doc_ca2)

IO.puts("Catalan: #{text_ca2}")

# Example 10: Entity Recognition (Catalan-specific)
IO.puts("\n10. Named Entity Recognition")
IO.puts("------------------------------")

entity_text = "En Joan viu a Barcelona i treballa a la Universitat de Catalunya."
IO.puts("Input: #{entity_text}")

{:ok, tokens_ent} = Catalan.tokenize(entity_text)
{:ok, tagged_ent} = Catalan.tag_pos(tokens_ent)

# Note: Entity recognition with Catalan lexicons
alias Nasty.Language.Catalan.EntityRecognizer
entities = EntityRecognizer.recognize(tagged_ent)

if length(entities) > 0 do
  IO.puts("\nEntities found:")
  Enum.each(entities, fn entity ->
    IO.puts("  #{entity.text} → #{entity.type} (confidence: #{Float.round(entity.confidence, 2)})")
  end)
else
  IO.puts("\nNo entities found (Catalan entity lexicons may need expansion)")
end

# Example 11: Catalan-specific Grammar Features
IO.puts("\n11. Catalan Grammar Features")
IO.puts("-----------------------------")

IO.puts("\nCatalan demonstrates:")
IO.puts("  - Pro-drop: Subject pronouns can be omitted")
IO.puts("  - Flexible word order: VSO possible in questions")
IO.puts("  - Post-nominal adjectives: 'casa gran' not 'gran casa'")
IO.puts("  - Interpunct in 'l·l': col·legi, intel·ligent")
IO.puts("  - Apostrophe contractions: l', d', s', n', m'")
IO.puts("  - Article contractions: del, al, pel, cal")

example_grammar = "Col·labora amb l'equip del professor."
{:ok, tokens_gram} = Catalan.tokenize(example_grammar)
{:ok, tagged_gram} = Catalan.tag_pos(tokens_gram)

IO.puts("\nExample: #{example_grammar}")
IO.puts("Features demonstrated:")
Enum.each(tagged_gram, fn token ->
  cond do
    String.contains?(token.text, "·") ->
      IO.puts("  - Interpunct: #{token.text}")
    String.contains?(token.text, "'") ->
      IO.puts("  - Apostrophe contraction: #{token.text}")
    token.text in ["del", "al", "pel"] ->
      IO.puts("  - Article contraction: #{token.text}")
    true ->
      :ok
  end
end)

IO.puts("\n========================================")
IO.puts("Catalan Example Complete!")
IO.puts("========================================\n")

# Helper functions

defp extract_phrase_text(phrase) do
  case phrase do
    %Nasty.AST.NounPhrase{} = np ->
      det = if np.determiner, do: np.determiner.text <> " ", else: ""
      mods = Enum.map(np.modifiers, & &1.text) |> Enum.join(" ")
      mods_str = if mods != "", do: mods <> " ", else: ""
      head = np.head.text
      post = Enum.map(np.post_modifiers, &extract_phrase_text/1) |> Enum.join(" ")
      post_str = if post != "", do: " " <> post, else: ""
      "#{det}#{mods_str}#{head}#{post_str}"
    
    %Nasty.AST.VerbPhrase{} = vp ->
      aux = Enum.map(vp.auxiliaries, & &1.text) |> Enum.join(" ")
      aux_str = if aux != "", do: aux <> " ", else: ""
      verb = vp.head.text
      comps = Enum.map(vp.complements, &extract_phrase_text/1) |> Enum.join(" ")
      comps_str = if comps != "", do: " " <> comps, else: ""
      "#{aux_str}#{verb}#{comps_str}"
    
    %Nasty.AST.PrepositionalPhrase{} = pp ->
      prep = pp.head.text
      obj = extract_phrase_text(pp.object)
      "#{prep} #{obj}"
    
    _ ->
      ""
  end
end

defp extract_noun_phrases(clause) do
  nps = []
  
  nps = if clause.subject && match?(%Nasty.AST.NounPhrase{}, clause.subject) do
    [clause.subject | nps]
  else
    nps
  end
  
  nps = if clause.predicate do
    vp = clause.predicate
    comp_nps = Enum.filter(vp.complements, &match?(%Nasty.AST.NounPhrase{}, &1))
    comp_nps ++ nps
  else
    nps
  end
  
  Enum.reverse(nps)
end
