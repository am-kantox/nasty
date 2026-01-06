defmodule Nasty.Language.English.POSTagger do
  @moduledoc """
  Part-of-Speech tagger for English using rule-based pattern matching.

  Tags tokens with Universal Dependencies POS tags based on:
  - Lexical lookup (closed-class words)
  - Morphological patterns (suffixes)
  - Context-based disambiguation

  This is a simple rule-based tagger. For better accuracy, consider
  using statistical models or neural networks in the future.

  ## Examples

      iex> alias Nasty.Language.English.{Tokenizer, POSTagger}
      iex> {:ok, tokens} = Tokenizer.tokenize("the")
      iex> {:ok, tagged} = POSTagger.tag_pos(tokens)
      iex> hd(tagged).pos_tag
      :det
  """

  alias Nasty.AST.Token

  @doc """
  Tags a list of tokens with POS tags.

  Uses:
  1. Lexical lookup for known words (determiners, pronouns, etc.)
  2. Morphological patterns (suffixes for verbs, nouns, adjectives)
  3. Context rules (e.g., word after determiner is likely a noun)

  ## Parameters

    - `tokens` - List of Token structs (from tokenizer)

  ## Returns

    - `{:ok, tokens}` - Tokens with updated pos_tag field
  """
  @spec tag_pos([Token.t()]) :: {:ok, [Token.t()]}
  def tag_pos(tokens) do
    tagged =
      tokens
      |> Enum.with_index()
      |> Enum.map(fn {token, idx} ->
        tag_token(token, tokens, idx)
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

      # Try lexical lookup first
      # Default fallback
      tag =
        lexical_tag(lowercase) ||
          morphological_tag(token.text) ||
          contextual_tag(token, all_tokens, idx) ||
          :noun

      %{token | pos_tag: tag}
    end
  end

  # Lexical lookup for closed-class words
  # Note: Order matters for ambiguous words
  defp lexical_tag(word) do
    cond do
      # Determiners first (includes possessives: my, your, his, her, its, our, their)
      word in determiners() -> :det
      # Pronouns (non-ambiguous ones)
      word in pronouns() -> :pron
      word in prepositions() -> :adp
      word in conjunctions_coord() -> :cconj
      word in conjunctions_sub() -> :sconj
      word in auxiliaries() -> :aux
      word in common_verbs() -> :verb
      word in common_adjectives() -> :adj
      word in adverbs() -> :adv
      word in particles() -> :part
      word in interjections() -> :intj
      true -> nil
    end
  end

  # Morphological tagging based on suffixes
  # credo:disable-for-lines:68
  defp morphological_tag(word) do
    cond do
      # Nouns (check specific noun suffixes first before other patterns)
      String.ends_with?(word, "tion") ->
        :noun

      String.ends_with?(word, "sion") ->
        :noun

      String.ends_with?(word, "ment") ->
        :noun

      String.ends_with?(word, "ness") ->
        :noun

      String.ends_with?(word, "ity") ->
        :noun

      String.ends_with?(word, "ism") ->
        :noun

      # Adverbs (specific suffix)
      String.ends_with?(word, "ly") and String.length(word) > 3 ->
        :adv

      # Verbs
      String.ends_with?(word, "ing") and String.length(word) > 4 ->
        :verb

      String.ends_with?(word, "ed") and String.length(word) > 3 ->
        :verb

      # Adjectives
      String.ends_with?(word, "ful") ->
        :adj

      String.ends_with?(word, "less") ->
        :adj

      String.ends_with?(word, "ous") ->
        :adj

      String.ends_with?(word, "ive") ->
        :adj

      String.ends_with?(word, "able") ->
        :adj

      String.ends_with?(word, "ible") ->
        :adj

      # Proper nouns (capitalized)
      String.first(word) == String.upcase(String.first(word)) and String.length(word) > 1 ->
        :propn

      # Nouns ending in -er/-or (less specific, so later)
      String.ends_with?(word, "er") and String.length(word) > 3 ->
        :noun

      String.ends_with?(word, "or") and String.length(word) > 3 ->
        :noun

      String.ends_with?(word, "ist") ->
        :noun

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
      # Object pronouns after verb or preposition: me, him, her, us, them
      (lowercase in ~w(me him her us them) and prev_token) &&
          prev_token.pos_tag in [:verb, :adp] ->
        :pron

      # After determiner -> likely noun
      prev_token && prev_token.pos_tag == :det ->
        :noun

      # After preposition -> likely noun
      prev_token && prev_token.pos_tag == :adp ->
        :noun

      # Before noun -> likely adjective
      next_token && next_token.pos_tag == :noun ->
        :adj

      true ->
        nil
    end
  end

  ## Word Lists (Closed-class words)

  defp determiners do
    ~w(
      the a an this that these those
      my your his her its our their
      some any no every each either neither
      much many more most less least few several all both half
      whose
    )
  end

  defp pronouns do
    # Note: ambiguous words (her, his, your, etc.) are in determiners list
    # and handled by default as determiners since that's more common
    ~w(
      i me mine myself
      you yours yourself yourselves
      he him himself
      she hers herself
      it itself
      we us ours ourselves
      they them theirs themselves
      who whom which what
      this that these those
      someone somebody something anyone anybody anything
      everyone everybody everything no one nobody nothing
    )
  end

  defp prepositions do
    ~w(
      in on at by for with from to of about
      above across after against along among around
      before behind below beneath beside between beyond
      down during except inside into like near
      off over past since through throughout till
      toward under underneath until up upon within without
    )
  end

  defp conjunctions_coord do
    ~w(and or but nor yet so for)
  end

  defp conjunctions_sub do
    ~w(
      after although as because before if once since
      than that though till unless until when whenever
      where wherever whether while
    )
  end

  defp auxiliaries do
    ~w(
      am is are was were be been being
      have has had having
      do does did doing
      will would shall should may might
      can could must ought
    )
  end

  defp adverbs do
    ~w(
      not very really quite rather too so enough
      always never often sometimes usually rarely seldom
      already yet still just now then soon
      here there everywhere nowhere anywhere somewhere
      how why when where
      indeed perhaps maybe probably possibly certainly
      however therefore moreover furthermore nevertheless nonetheless
    )
  end

  defp particles do
    ~w(to up down out off in on away back)
  end

  defp interjections do
    ~w(
      ah oh wow hey hi hello goodbye yes no thanks please
      ouch oops ugh hmm huh
    )
  end

  defp common_verbs do
    ~w(
      go went gone going goes
      come came coming comes
      see saw seen seeing sees
      get got gotten getting gets
      make made making makes
      know knew known knowing knows
      think thought thinking thinks
      take took taken taking takes
      find found finding finds
      give gave given giving gives
      tell told telling tells
      work worked working works
      call called calling calls
      try tried trying tries
      ask asked asking asks
      need needed needing needs
      feel felt feeling feels
      become became becoming becomes
      leave left leaving leaves
      put putting puts
      mean meant meaning means
      keep kept keeping keeps
      let letting lets
      begin began begun beginning begins
      seem seemed seeming seems
      help helped helping helps
      show showed shown showing shows
      hear heard hearing hears
      play played playing plays
      run ran running runs
      move moved moving moves
      like liked liking likes
      live lived living lives
      believe believed believing believes
      bring brought bringing brings
      happen happened happening happens
      write wrote written writing writes
      sit sat sitting sits
      stand stood standing stands
      lose lost losing loses
      pay paid paying pays
      meet met meeting meets
      include included including includes
      continue continued continuing continues
      set setting sets
      learn learned learning learns
      change changed changing changes
      lead led leading leads
      understand understood understanding understands
      watch watched watching watches
      follow followed following follows
      stop stopped stopping stops
      create created creating creates
      speak spoke spoken speaking speaks
      read reading reads
      spend spent spending spends
      grow grew grown growing grows
      open opened opening opens
      walk walked walking walks
      win won winning wins
      teach taught teaching teaches
      offer offered offering offers
      remember remembered remembering remembers
      consider considered considering considers
      appear appeared appearing appears
      buy bought buying buys
      serve served serving serves
      die died dying dies
      send sent sending sends
      build built building builds
      stay stayed staying stays
      fall fell fallen falling falls
      cut cutting cuts
      reach reached reaching reaches
      kill killed killing kills
      raise raised raising raises
      pass passed passing passes
      sell sold selling sells
      decide decided deciding decides
      return returned returning returns
      explain explained explaining explains
      hope hoped hoping hopes
      develop developed developing develops
      carry carried carrying carries
      break broke broken breaking breaks
      receive received receiving receives
      agree agreed agreeing agrees
      support supported supporting supports
      hit hitting hits
      produce produced producing produces
      eat ate eaten eating eats
      cover covered covering covers
      catch caught catching catches
      draw drew drawn drawing draws
    )
  end

  defp common_adjectives do
    ~w(
      good bad big small large little
      new old young long short
      high low great right left
      different same next last
      early late public important
      able free real sure
      certain wrong ready clear
      white black red blue green
      hot cold open happy sad
      easy hard strong weak
      full empty rich poor
      heavy light fast slow
      clean dirty safe dangerous
      cheap expensive quiet loud
      wide narrow deep shallow
      thick thin bright dark
      soft hard smooth rough
      wet dry simple complex
      common rare perfect terrible
      beautiful ugly wonderful awful
      excellent bad fine nice
      popular famous special normal
      main central natural human
      social economic political legal
      international national local private
      general particular individual specific
      recent modern current past
      future present certain possible
      likely similar different various
      several additional extra available
      necessary essential important serious
      major minor primary secondary
      positive negative active passive
      direct indirect wild calm
      brief brief enormous tiny
      huge massive grand minor
    )
  end
end
