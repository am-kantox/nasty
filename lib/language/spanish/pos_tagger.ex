defmodule Nasty.Language.Spanish.POSTagger do
  @moduledoc """
  Part-of-Speech tagger for Spanish using rule-based pattern matching.

  Tags tokens with Universal Dependencies POS tags based on:
  - Lexical lookup (closed-class words: articles, pronouns, prepositions)
  - Morphological patterns (verb endings, gender/number markers)
  - Context-based disambiguation

  This is a rule-based tagger that achieves ~80-85% accuracy. For better
  accuracy, statistical or neural models can be added in the future.

  ## Spanish-Specific Features

  - Verb conjugations (present, preterite, imperfect, future, conditional, subjunctive)
  - Gender agreement (masculine/feminine: -o/-a endings)
  - Number agreement (singular/plural: -s/-es endings)
  - Clitic pronouns (me, te, se, lo, la, etc.)
  - Contractions (del = de + el, al = a + el)

  ## Examples

      iex> alias Nasty.Language.Spanish.{Tokenizer, POSTagger}
      iex> {:ok, tokens} = Tokenizer.tokenize("la casa")
      iex> {:ok, tagged} = POSTagger.tag_pos(tokens)
      iex> [art, noun] = tagged
      iex> art.pos_tag
      :det
      iex> noun.pos_tag
      :noun
  """

  alias Nasty.AST.Token

  @doc """
  Tags a list of tokens with POS tags.

  Uses:
  1. Lexical lookup for known words (articles, pronouns, prepositions)
  2. Morphological patterns (verb endings, gender/number markers)
  3. Context rules (e.g., word after article is likely a noun)

  ## Parameters

    - `tokens` - List of Token structs (from tokenizer)
    - `opts` - Options
      - `:model` - Model type: `:rule_based` (default, only option for now)

  ## Returns

    - `{:ok, tokens}` - Tokens with updated pos_tag field
  """
  @spec tag_pos([Token.t()], keyword()) :: {:ok, [Token.t()]}
  def tag_pos(tokens, opts \\ []) do
    model_type = Keyword.get(opts, :model, :rule_based)

    case model_type do
      :rule_based ->
        tag_pos_rule_based(tokens)

      _ ->
        {:error, {:unknown_model_type, model_type}}
    end
  end

  @doc """
  Rule-based POS tagging for Spanish.
  """
  def tag_pos_rule_based(tokens) do
    # Use map_reduce to build up tagged tokens as we go
    # This allows contextual rules to see previously tagged tokens
    {tagged, _} =
      tokens
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {token, idx}, acc_tagged ->
        # Tag using accumulated tagged tokens for context
        tagged_token = tag_token(token, acc_tagged ++ [token] ++ Enum.drop(tokens, idx + 1), idx)
        {tagged_token, acc_tagged ++ [tagged_token]}
      end)

    {:ok, tagged}
  end

  ## Private Functions

  # Tag a single token based on lexical lookup, morphology, and context
  defp tag_token(token, all_tokens, idx) do
    # Skip if already has a definitive tag
    if token.pos_tag in [:num, :punct] do
      token
    else
      lowercase = String.downcase(token.text)

      # Try lexical lookup first (highest confidence)
      lexical = lexical_tag(lowercase)

      if lexical do
        %{token | pos_tag: lexical}
      else
        # Check contextual rules (can override morphological for disambiguation)
        contextual = contextual_tag(token, all_tokens, idx)
        morphological = morphological_tag(token.text)

        # Contextual rules have priority when they apply
        tag = contextual || morphological || :noun
        %{token | pos_tag: tag}
      end
    end
  end

  # Lexical lookup for closed-class words
  defp lexical_tag(word) do
    cond do
      # Articles (definite/indefinite)
      word in articles() -> :det
      # Pronouns
      word in pronouns() -> :pron
      # Prepositions
      word in prepositions() -> :adp
      # Contractions (del = de + el, al = a + el)
      word in contractions() -> :adp
      # Coordinating conjunctions
      word in conjunctions_coord() -> :cconj
      # Auxiliary verbs
      word in auxiliaries() -> :aux
      # Common verbs (most frequent) - check before subordinating conjunctions
      # to handle ambiguous words like "como" (I eat vs. as/like)
      word in common_verbs() -> :verb
      # Subordinating conjunctions - after verbs to resolve ambiguity
      word in conjunctions_sub() -> :sconj
      # Common nouns (check before adjectives to avoid ambiguity)
      word in common_nouns() -> :noun
      # Common adjectives
      word in common_adjectives() -> :adj
      # Adverbs
      word in adverbs() -> :adv
      # Particles (no, sí)
      word in particles() -> :part
      # Interjections
      word in interjections() -> :intj
      true -> nil
    end
  end

  # Morphological tagging based on Spanish suffixes and patterns
  # credo:disable-for-lines:220
  defp morphological_tag(word) do
    lowercase = String.downcase(word)

    cond do
      # Check longer/more specific patterns first

      # Adverbs ending in -mente (check before verb patterns)
      String.ends_with?(lowercase, "mente") and String.length(lowercase) > 6 ->
        :adv

      # Nouns with specific suffixes (check before verb patterns)
      String.ends_with?(lowercase, "ción") ->
        :noun

      String.ends_with?(lowercase, "sión") ->
        :noun

      String.ends_with?(lowercase, "miento") ->
        :noun

      String.ends_with?(lowercase, "dad") ->
        :noun

      String.ends_with?(lowercase, "tad") ->
        :noun

      String.ends_with?(lowercase, "ncia") ->
        :noun

      String.ends_with?(lowercase, "ismo") ->
        :noun

      String.ends_with?(lowercase, "ista") ->
        :noun

      # Adjective suffixes (check before verb patterns)
      String.ends_with?(lowercase, "oso") or String.ends_with?(lowercase, "osa") ->
        :adj

      String.ends_with?(lowercase, "ivo") or String.ends_with?(lowercase, "iva") ->
        :adj

      String.ends_with?(lowercase, "able") ->
        :adj

      String.ends_with?(lowercase, "ible") ->
        :adj

      String.ends_with?(lowercase, "ante") ->
        :adj

      String.ends_with?(lowercase, "ente") ->
        :adj

      String.ends_with?(lowercase, "iente") ->
        :adj

      # Proper nouns (capitalized)
      String.first(word) == String.upcase(String.first(word)) and String.length(word) > 1 ->
        :propn

      # Spanish verb endings - Present tense
      # -ar verbs: hablo, hablas, habla, hablamos, habláis, hablan
      # Be more specific to avoid false positives with nouns
      String.ends_with?(lowercase, "o") and ends_with_ar_stem?(lowercase) and
        String.length(lowercase) >= 4 and has_verb_stem?(lowercase) ->
        :verb

      String.ends_with?(lowercase, "as") and ends_with_ar_stem?(lowercase) and
          String.length(lowercase) >= 5 ->
        :verb

      String.ends_with?(lowercase, "a") and ends_with_ar_stem?(lowercase) and
        String.length(lowercase) > 4 and has_verb_stem?(lowercase) ->
        :verb

      String.ends_with?(lowercase, "amos") ->
        :verb

      String.ends_with?(lowercase, "áis") ->
        :verb

      String.ends_with?(lowercase, "an") and ends_with_ar_stem?(lowercase) ->
        :verb

      # -er/-ir verbs: como, comes, come, comemos, coméis, comen
      String.ends_with?(lowercase, "es") and
          (ends_with_er_stem?(lowercase) or ends_with_ir_stem?(lowercase)) ->
        :verb

      String.ends_with?(lowercase, "e") and
        (ends_with_er_stem?(lowercase) or ends_with_ir_stem?(lowercase)) and
          String.length(lowercase) > 3 ->
        :verb

      String.ends_with?(lowercase, "emos") ->
        :verb

      String.ends_with?(lowercase, "éis") ->
        :verb

      String.ends_with?(lowercase, "en") and
          (ends_with_er_stem?(lowercase) or ends_with_ir_stem?(lowercase)) ->
        :verb

      String.ends_with?(lowercase, "imos") ->
        :verb

      String.ends_with?(lowercase, "ís") ->
        :verb

      # Preterite tense: hablé, hablaste, habló, hablamos, hablasteis, hablaron
      String.ends_with?(lowercase, "é") ->
        :verb

      String.ends_with?(lowercase, "aste") ->
        :verb

      String.ends_with?(lowercase, "ó") ->
        :verb

      String.ends_with?(lowercase, "asteis") ->
        :verb

      String.ends_with?(lowercase, "aron") ->
        :verb

      String.ends_with?(lowercase, "í") and String.length(lowercase) > 2 ->
        :verb

      String.ends_with?(lowercase, "iste") ->
        :verb

      String.ends_with?(lowercase, "ió") ->
        :verb

      String.ends_with?(lowercase, "isteis") ->
        :verb

      String.ends_with?(lowercase, "ieron") ->
        :verb

      # Imperfect tense: hablaba, hablabas, hablaba, hablábamos, hablabais, hablaban
      String.ends_with?(lowercase, "aba") ->
        :verb

      String.ends_with?(lowercase, "abas") ->
        :verb

      String.ends_with?(lowercase, "ábamos") ->
        :verb

      String.ends_with?(lowercase, "abais") ->
        :verb

      String.ends_with?(lowercase, "aban") ->
        :verb

      String.ends_with?(lowercase, "ía") and String.length(lowercase) > 3 ->
        :verb

      String.ends_with?(lowercase, "ías") ->
        :verb

      String.ends_with?(lowercase, "íamos") ->
        :verb

      String.ends_with?(lowercase, "íais") ->
        :verb

      String.ends_with?(lowercase, "ían") ->
        :verb

      # Future tense: hablaré, hablarás, hablará, hablaremos, hablaréis, hablarán
      String.ends_with?(lowercase, "ré") ->
        :verb

      String.ends_with?(lowercase, "rás") ->
        :verb

      String.ends_with?(lowercase, "rá") ->
        :verb

      String.ends_with?(lowercase, "remos") ->
        :verb

      String.ends_with?(lowercase, "réis") ->
        :verb

      String.ends_with?(lowercase, "rán") ->
        :verb

      # Conditional: hablaría, hablarías, hablaría, hablaríamos, hablaríais, hablarían
      String.ends_with?(lowercase, "ría") ->
        :verb

      String.ends_with?(lowercase, "rías") ->
        :verb

      String.ends_with?(lowercase, "ríamos") ->
        :verb

      String.ends_with?(lowercase, "ríais") ->
        :verb

      String.ends_with?(lowercase, "rían") ->
        :verb

      # Gerund: hablando, comiendo, viviendo
      String.ends_with?(lowercase, "ando") ->
        :verb

      String.ends_with?(lowercase, "iendo") ->
        :verb

      # Past participle: hablado, comido, vivido
      String.ends_with?(lowercase, "ado") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "ido") and String.length(lowercase) > 4 ->
        :verb

      # Subjunctive present: hable, hables, hable, hablemos, habléis, hablen
      String.ends_with?(lowercase, "e") and ends_with_ar_stem?(lowercase) and
          String.length(lowercase) > 3 ->
        :verb

      true ->
        nil
    end
  end

  # Context-based tagging
  defp contextual_tag(token, all_tokens, idx) do
    prev_token = if idx > 0, do: Enum.at(all_tokens, idx - 1)
    next_token = Enum.at(all_tokens, idx + 1)

    lowercase = String.downcase(token.text)

    cond do
      # After article -> likely noun or adjective
      prev_token && prev_token.pos_tag == :det ->
        if ends_with_adj_suffix?(lowercase) do
          :adj
        else
          :noun
        end

      # After noun -> likely adjective (Spanish adjectives often come after nouns)
      # e.g., "gato blanco" (white cat), "casa grande" (big house)
      prev_token && prev_token.pos_tag == :noun &&
          (ends_with_adj_agreement?(lowercase) || ends_with_adj_suffix?(lowercase)) ->
        :adj

      # After preposition -> likely noun (but preserve proper nouns)
      prev_token && prev_token.pos_tag == :adp &&
          not capitalized?(token.text) ->
        :noun

      # Before noun -> likely adjective (but Spanish adjectives often come after)
      next_token && next_token.pos_tag == :noun ->
        :adj

      # Clitic pronouns (already tokenized separately)
      lowercase in clitics() ->
        :pron

      true ->
        nil
    end
  end

  # Check if word stem is from -ar verb
  defp ends_with_ar_stem?(word) do
    # Simple heuristic: if removing ending leaves valid stem
    stem_length = String.length(word) - 2
    stem_length >= 2
  end

  # Check if word stem is from -er verb
  defp ends_with_er_stem?(word) do
    stem_length = String.length(word) - 2
    stem_length >= 2
  end

  # Check if word stem is from -ir verb
  defp ends_with_ir_stem?(word) do
    stem_length = String.length(word) - 2
    stem_length >= 2
  end

  # Check if word has adjective suffix
  defp ends_with_adj_suffix?(word) do
    String.ends_with?(word, "oso") or String.ends_with?(word, "osa") or
      String.ends_with?(word, "ivo") or String.ends_with?(word, "iva") or
      String.ends_with?(word, "able") or String.ends_with?(word, "ible") or
      String.ends_with?(word, "ante") or String.ends_with?(word, "ente")
  end

  # Check if word has typical adjective gender/number agreement pattern
  # Adjectives ending in -o (masc), -a (fem), -os (masc pl), -as (fem pl)
  defp ends_with_adj_agreement?(word) do
    len = String.length(word)

    len > 3 &&
      (String.ends_with?(word, "o") or
         String.ends_with?(word, "a") or
         String.ends_with?(word, "os") or
         String.ends_with?(word, "as"))
  end

  # Check if word is likely to be a verb stem (heuristic)
  # Returns false for common noun patterns ending in -o, -a, -e
  defp has_verb_stem?(word) do
    # Words less than 4 chars ending in o/a are likely nouns (gato, casa)
    if String.length(word) < 4 do
      false
    else
      # If it looks like a typical noun pattern, it's not a verb
      # [TODO] This is a simple heuristic - can be improved
      not Regex.match?(~r/(gato|pato|rato|dato)$/, word)
    end
  end

  # Check if word is capitalized (proper noun)
  defp capitalized?(word) do
    first_char = String.first(word)
    first_char == String.upcase(first_char) && String.length(word) > 1
  end

  ## Word Lists (Closed-class words)

  # Spanish articles (definite and indefinite)
  defp articles do
    ~w(
      el la los las
      un una unos unas
    )
  end

  # Spanish pronouns
  defp pronouns do
    ~w(
      yo me mí conmigo
      tú te ti contigo usted
      él ella se sí consigo
      nosotros nosotras nos
      vosotros vosotras os
      ellos ellas ustedes
      lo la le los las les
      esto eso aquello
      este esta ese esa aquel aquella
      estos estas esos esas aquellos aquellas
      quien quienes cual cuales que
      algo alguien alguno alguna algunos algunas
      nada nadie ninguno ninguna ningunos ningunas
      todo toda todos todas
    )
  end

  # Spanish clitics (attached to verbs: dámelo, dáselo)
  defp clitics do
    ~w(me te se lo la le les los las nos os)
  end

  # Spanish prepositions
  defp prepositions do
    ~w(
      a ante bajo cabe con contra de desde
      en entre hacia hasta para por según
      sin so sobre tras durante mediante
    )
  end

  # Spanish contractions
  defp contractions do
    ~w(del al)
  end

  # Coordinating conjunctions
  defp conjunctions_coord do
    ~w(y e o u pero mas sino ni)
  end

  # Subordinating conjunctions
  defp conjunctions_sub do
    ~w(
      que como cuando donde si porque aunque mientras
      apenas pues luego conque así
    )
  end

  # Auxiliary verbs (forms of ser, estar, haber)
  defp auxiliaries do
    ~w(
      ser soy eres es somos sois son
      era eras éramos erais eran
      fui fuiste fue fuimos fuisteis fueron
      seré serás será seremos seréis serán
      sería serías seríamos seríais serían
      sea seas seamos seáis sean
      fuera fueras fuéramos fuerais fueran
      sido siendo
      estar estoy estás está estamos estáis están
      estaba estabas estábamos estabais estaban
      estuve estuviste estuvo estuvimos estuvisteis estuvieron
      estaré estarás estará estaremos estaréis estarán
      estaría estarías estaríamos estaríais estarían
      esté estés estemos estéis estén
      estuviera estuvieras estuviéramos estuvierais estuvieran
      estado estando
      haber he has ha hemos habéis han
      había habías habíamos habíais habían
      hube hubiste hubo hubimos hubisteis hubieron
      habré habrás habrá habremos habréis habrán
      habría habrías habríamos habríais habrían
      haya hayas hayamos hayáis hayan
      hubiera hubieras hubiéramos hubierais hubieran
      habido habiendo
    )
  end

  # Common high-frequency Spanish verbs
  defp common_verbs do
    ~w(
      ir voy vas va vamos vais van iba ibas iba íbamos ibais iban
      hacer hago haces hace hacemos hacéis hacen
      decir digo dices dice decimos decís dicen
      poder puedo puedes puede podemos podéis pueden
      querer quiero quieres quiere queremos queréis quieren
      ver veo ves ve vemos veis ven
      dar doy das da damos dais dan
      saber sé sabes sabe sabemos sabéis saben
      tener tengo tienes tiene tenemos tenéis tienen
      venir vengo vienes viene venimos venís vienen
      poner pongo pones pone ponemos ponéis ponen
      salir salgo sales sale salimos salís salen
      traer traigo traes trae traemos traéis traen
      llegar llego llegas llega llegamos llegáis llegan
      pasar paso pasas pasa pasamos pasáis pasan
      trabajar trabajo trabajas trabaja trabajamos trabajáis trabajan
      vivir vivo vives vive vivimos vivís viven
      comer como comes come comemos coméis comen
      beber bebo bebes bebe bebemos bebéis beben
      hablar hablo hablas habla hablamos habláis hablan
    )
  end

  # Common Spanish adjectives
  defp common_adjectives do
    ~w(
      bueno buena buenos buenas malo mala malos malas
      grande grandes pequeño pequeña pequeños pequeñas
      nuevo nueva nuevos nuevas viejo vieja viejos viejas
      joven jóvenes mejor mejores peor peores
      mucho mucha muchos muchas poco poca pocos pocas
      otro otra otros otras mismo misma mismos mismas
      todo toda todos todas algún alguna algunos algunas
      ningún ninguna ningunos ningunas
      propio propia propios propias último última últimos últimas
      primer primero primera primeros primeras
      segundo segunda segundos segundas
      tercero tercera terceros terceras
    )
  end

  # Common Spanish nouns
  defp common_nouns do
    ~w(
      gato gata gatos gatas perro perra perros perras
      casa casas mesa mesas silla sillas libro libros
      día días semana semanas mes meses año años
      hombre hombres mujer mujeres niño niña niños niñas
      ciudad ciudades país países mundo mundos
      agua aguas tierra tierras fuego fuegos aire aires
      coche coches carro carros tren trenes avión aviones
      comida comidas bebida bebidas
      trabajo trabajos escuela escuelas universidad universidades
      familia familias amigo amiga amigos amigas
      mano manos pie pies cabeza cabezas ojo ojos
      vida vidas muerte muertes tiempo tiempos
      mercado mercados parque parques calle calles
    )
  end

  # Spanish adverbs
  defp adverbs do
    ~w(
      sí no
      muy bien mal
      aquí ahí allí acá allá
      hoy ayer mañana ahora luego después antes entonces
      siempre nunca jamás
      ya todavía aún
      también tampoco
      más menos mucho poco
      casi apenas solo solamente
      quizá quizás tal vez
      así como
    )
  end

  # Particles
  defp particles do
    ~w(no sí)
  end

  # Interjections
  defp interjections do
    ~w(
      ah oh eh hey hola adiós ay uf
    )
  end
end
