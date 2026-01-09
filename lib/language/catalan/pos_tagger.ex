defmodule Nasty.Language.Catalan.POSTagger do
  @moduledoc """
  Part-of-Speech tagger for Catalan using rule-based pattern matching.

  Tags tokens with Universal Dependencies POS tags based on:
  - Lexical lookup (closed-class words: articles, pronouns, prepositions)
  - Morphological patterns (verb endings, gender/number markers)
  - Context-based disambiguation

  ## Catalan-Specific Features

  - Verb conjugations (present, preterite, imperfect, future, conditional, subjunctive)
  - Gender agreement (masculine/feminine: -o/-a, -e endings)
  - Number agreement (singular/plural: -s/-es endings)
  - Clitic pronouns (em, et, es, el, la, etc.)
  - Contractions (del = de + el, al = a + el, pel = per + el)
  - Interpunct words (col·laborar, intel·ligent)
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
  Rule-based POS tagging for Catalan.
  """
  def tag_pos_rule_based(tokens) do
    {tagged, _} =
      tokens
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {token, idx}, acc_tagged ->
        tagged_token = tag_token(token, acc_tagged ++ [token] ++ Enum.drop(tokens, idx + 1), idx)
        {tagged_token, acc_tagged ++ [tagged_token]}
      end)

    {:ok, tagged}
  end

  ## Private Functions

  defp tag_token(token, all_tokens, idx) do
    if token.pos_tag in [:num, :punct] do
      token
    else
      lowercase = String.downcase(token.text)
      lexical = lexical_tag(lowercase)

      if lexical do
        %{token | pos_tag: lexical}
      else
        contextual = contextual_tag(token, all_tokens, idx)
        morphological = morphological_tag(token.text)
        tag = contextual || morphological || :noun
        %{token | pos_tag: tag}
      end
    end
  end

  defp lexical_tag(word) do
    cond do
      word in articles() -> :det
      word in pronouns() -> :pron
      word in prepositions() -> :adp
      word in contractions() -> :adp
      word in conjunctions_coord() -> :cconj
      word in auxiliaries() -> :aux
      word in common_verbs() -> :verb
      word in conjunctions_sub() -> :sconj
      word in common_nouns() -> :noun
      word in common_adjectives() -> :adj
      word in adverbs() -> :adv
      word in particles() -> :part
      word in interjections() -> :intj
      # Single letter apostrophe contractions - l' is determiner, d' is preposition
      word == "l'" -> :det
      word in ["d'", "s'", "n'", "m'", "t'"] -> :adp
      true -> nil
    end
  end

  # credo:disable-for-lines:200
  defp morphological_tag(word) do
    lowercase = String.downcase(word)

    cond do
      String.ends_with?(lowercase, "ment") and String.length(lowercase) > 6 ->
        :adv

      String.ends_with?(lowercase, "ció") ->
        :noun

      String.ends_with?(lowercase, "sió") ->
        :noun

      String.ends_with?(lowercase, "ment") and String.length(lowercase) > 5 ->
        :noun

      String.ends_with?(lowercase, "dat") ->
        :noun

      String.ends_with?(lowercase, "tat") ->
        :noun

      String.ends_with?(lowercase, "ància") ->
        :noun

      String.ends_with?(lowercase, "isme") ->
        :noun

      String.ends_with?(lowercase, "ista") ->
        :noun

      String.ends_with?(lowercase, "ós") or String.ends_with?(lowercase, "osa") ->
        :adj

      String.ends_with?(lowercase, "iu") or String.ends_with?(lowercase, "iva") ->
        :adj

      String.ends_with?(lowercase, "able") ->
        :adj

      String.ends_with?(lowercase, "ible") ->
        :adj

      String.ends_with?(lowercase, "ant") and String.length(lowercase) <= 4 ->
        :adj

      String.ends_with?(lowercase, "ent") and String.length(lowercase) <= 4 ->
        :adj

      # Gerunds ending in -ar (before proper noun check)
      String.ends_with?(lowercase, "ar") and String.length(lowercase) > 4 and
          String.contains?(lowercase, "·") ->
        :verb

      String.first(word) == String.upcase(String.first(word)) and String.length(word) > 1 ->
        :propn

      # Catalan verb endings - Present tense -ar verbs
      String.ends_with?(lowercase, "o") and String.length(lowercase) >= 4 ->
        :verb

      String.ends_with?(lowercase, "es") and String.length(lowercase) >= 5 ->
        :verb

      String.ends_with?(lowercase, "a") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "em") and String.length(lowercase) > 3 ->
        :verb

      String.ends_with?(lowercase, "eu") and String.length(lowercase) > 3 ->
        :verb

      String.ends_with?(lowercase, "en") and String.length(lowercase) > 3 ->
        :verb

      # Present tense -re/-ir verbs
      String.ends_with?(lowercase, "eixo") ->
        :verb

      String.ends_with?(lowercase, "eixes") ->
        :verb

      String.ends_with?(lowercase, "eix") ->
        :verb

      String.ends_with?(lowercase, "im") and String.length(lowercase) > 3 ->
        :verb

      String.ends_with?(lowercase, "m") and String.length(lowercase) >= 4 ->
        :verb

      String.ends_with?(lowercase, "iu") and String.length(lowercase) > 3 ->
        :verb

      # Preterite (perfet simple)
      String.ends_with?(lowercase, "í") and String.length(lowercase) > 2 ->
        :verb

      String.ends_with?(lowercase, "ares") ->
        :verb

      String.ends_with?(lowercase, "à") ->
        :verb

      String.ends_with?(lowercase, "àrem") ->
        :verb

      String.ends_with?(lowercase, "àreu") ->
        :verb

      String.ends_with?(lowercase, "aren") ->
        :verb

      # Imperfect (imperfet)
      String.ends_with?(lowercase, "ava") ->
        :verb

      String.ends_with?(lowercase, "aves") ->
        :verb

      String.ends_with?(lowercase, "àvem") ->
        :verb

      String.ends_with?(lowercase, "àveu") ->
        :verb

      String.ends_with?(lowercase, "aven") ->
        :verb

      String.ends_with?(lowercase, "ia") and String.length(lowercase) > 3 ->
        :verb

      String.ends_with?(lowercase, "ies") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "íem") ->
        :verb

      String.ends_with?(lowercase, "íeu") ->
        :verb

      String.ends_with?(lowercase, "ien") and String.length(lowercase) > 4 ->
        :verb

      # Future
      String.ends_with?(lowercase, "ré") ->
        :verb

      String.ends_with?(lowercase, "ràs") ->
        :verb

      String.ends_with?(lowercase, "rà") ->
        :verb

      String.ends_with?(lowercase, "rem") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "reu") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "ran") and String.length(lowercase) > 4 ->
        :verb

      # Conditional
      String.ends_with?(lowercase, "ria") ->
        :verb

      String.ends_with?(lowercase, "ries") ->
        :verb

      String.ends_with?(lowercase, "ríem") ->
        :verb

      String.ends_with?(lowercase, "ríeu") ->
        :verb

      String.ends_with?(lowercase, "rien") ->
        :verb

      # Gerund
      String.ends_with?(lowercase, "ant") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "ent") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "int") ->
        :verb

      # Past participle
      String.ends_with?(lowercase, "at") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "ut") and String.length(lowercase) > 4 ->
        :verb

      String.ends_with?(lowercase, "it") and String.length(lowercase) > 4 ->
        :verb

      true ->
        nil
    end
  end

  defp contextual_tag(token, all_tokens, idx) do
    prev_token = if idx > 0, do: Enum.at(all_tokens, idx - 1)
    next_token = Enum.at(all_tokens, idx + 1)
    lowercase = String.downcase(token.text)

    cond do
      prev_token && prev_token.pos_tag == :det ->
        if ends_with_adj_suffix?(lowercase) do
          :adj
        else
          :noun
        end

      prev_token && prev_token.pos_tag == :noun && ends_with_adj_suffix?(lowercase) ->
        :adj

      prev_token && prev_token.pos_tag == :adp && not capitalized?(token.text) ->
        :noun

      next_token && next_token.pos_tag == :noun ->
        :adj

      lowercase in clitics() ->
        :pron

      true ->
        nil
    end
  end

  defp ends_with_adj_suffix?(word) do
    String.ends_with?(word, "ós") or String.ends_with?(word, "osa") or
      String.ends_with?(word, "iu") or String.ends_with?(word, "iva") or
      String.ends_with?(word, "able") or String.ends_with?(word, "ible") or
      String.ends_with?(word, "ant") or String.ends_with?(word, "ent")
  end

  defp capitalized?(word) do
    first_char = String.first(word)
    first_char == String.upcase(first_char) && String.length(word) > 1
  end

  ## Word Lists

  defp articles do
    ~w(el la els les l' un una uns unes)
  end

  defp pronouns do
    ~w(
      jo em mi
      tu et ti
      ell ella es se si
      nosaltres ens
      vosaltres us
      ells elles
      el la lo els les los
      això allò açò
      aquest aquesta aquests aquestes
      aquell aquella aquells aquelles
      qui quin quina quins quines que
      algú alguna alguns algunes
      res ningú cap
      tot tota tots totes
    )
  end

  defp clitics do
    ~w(em et es el la els les en hi ho)
  end

  defp prepositions do
    ~w(
      a amb cap contra de des durant en entre fins
      per sense sobre vers cap durant mitjançant
    )
  end

  defp contractions do
    ~w(del al pel)
  end

  defp conjunctions_coord do
    ~w(i o però mas ni però o u)
  end

  defp conjunctions_sub do
    ~w(
      que com quan on si perquè encara mentre
      així doncs puix ja
    )
  end

  defp auxiliaries do
    ~w(
      ser sóc ets és som sou són
      era eres érem éreu eren
      fui vas fou fórem fóreu foren
      seré seràs serà serem sereu seran
      seria series seríem seríeu serien
      sigui siguis siguem sigueu siguin
      fos fossis fóssim fóssiu fossin
      estat essent
      estar estic estàs està estem esteu estan
      estava estaves estàvem estàveu estaven
      estaré estaràs estarà estarem estareu estaran
      estaria estaries estaríem estaríeu estarien
      estigui estiguis estiguem estigueu estiguin
      estat estant
      haver he has ha hem heu han
      havia havies havíem havíeu havien
      hauré hauràs haurà haurem haureu hauran
      hauria hauries hauríem hauríeu haurien
      hagi hagis hàgim hàgiu hagin
      hagut havent
    )
  end

  defp common_verbs do
    ~w(
      anar vaig vas va anem aneu van anava
      fer faig fas fa fem feu fan
      dir dic dius diu diem dieu diuen
      poder puc pots pot podem podeu poden
      voler vull vols vol volem voleu volen
      veure veig veus veu veiem veieu veuen
      donar dono dones dona donem doneu donen
      saber sé saps sap sabem sabeu saben
      tenir tinc tens té tenim teniu tenen
      venir vinc véns ve venim veniu vénen
      posar poso poses posa posem poseu posen
      sortir surto surts surt sortim sortiu surten
      arribar arribo arribes arriba arribem arribeu arriben
      passar passo passes passa passem passeu passen
      treballar treballo treballes treballa treballem treballeu treballen
      viure visc vius viu vivim viviu viuen
      menjar menjo menges menja mengem mengeu mengen
      beure bec beus beu bevem beveu beuen
      parlar parlo parles parla parlem parleu parlen
    )
  end

  defp common_adjectives do
    ~w(
      bo bona bons bones dolent dolenta dolents dolentes
      gran grans petit petita petits petites
      nou nova nous noves vell vella vells velles
      jove joves millor millors pitjor pitjors
      molt molta molts moltes poc poca pocs poques
      altre altra altres mateix mateixa mateixos mateixes
      tot tota tots totes algun alguna alguns algunes
      cap
      propi pròpia propis pròpies últim última últims últimes
      primer primera primers primeres
      segon segona segons segones
      tercer tercera tercers terceres
    )
  end

  defp common_nouns do
    ~w(
      gat gata gats gates gos gossa gossos gosses
      casa cases taula taules cadira cadires llibre llibres
      dia dies setmana setmanes mes mesos any anys
      home homes dona dones nen nena nens nenes
      ciutat ciutats país països món móns
      aigua aigües terra terres foc focs aire aires
      cotxe cotxes tren trens avió avions
      menjar menjars beguda begudes
      treball treballs escola escoles universitat universitats
      família famílies amic amiga amics amigues
      mà mans peu peus cap caps ull ulls
      vida vides mort morts temps
      mercat mercats parc parcs carrer carrers
    )
  end

  defp adverbs do
    ~w(
      sí no
      molt bé mal
      aquí allà allí ara després abans llavors
      sempre mai
      ja encara
      també tampoc
      més menys molt poc
      gairebé només
      potser
      així com
    )
  end

  defp particles do
    ~w(no sí)
  end

  defp interjections do
    ~w(ah oh eh hola adéu ai uf)
  end
end
