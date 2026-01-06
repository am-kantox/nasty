defmodule Nasty.Rendering.Text do
  @moduledoc """
  Renders AST nodes back to natural language text.

  This module implements surface realization: converting the abstract
  syntactic structure back into readable text with proper word order,
  agreement, punctuation, and capitalization.

  ## Features

  - Surface realization (choose word forms)
  - Agreement (subject-verb, determiner-noun)
  - Word order (handle variations)
  - Punctuation insertion
  - Formatting (capitalization, spacing)

  ## Examples

      iex> token = %Nasty.AST.Token{text: "cat", pos_tag: :noun, language: :en, span: span}
      iex> Nasty.Rendering.Text.render(token)
      {:ok, "cat"}

      iex> Nasty.Rendering.Text.render(document)
      {:ok, "The quick brown fox jumps over the lazy dog."}
  """

  alias Nasty.AST.{
    AdjectivalPhrase,
    AdverbialPhrase,
    Clause,
    Document,
    NounPhrase,
    Paragraph,
    PrepositionalPhrase,
    Sentence,
    Token,
    VerbPhrase
  }

  @typedoc """
  Rendering options.

  - `:capitalize_sentences` - Whether to capitalize first word of sentences (default: true)
  - `:add_punctuation` - Whether to add sentence-ending punctuation (default: true)
  - `:paragraph_separator` - String to separate paragraphs (default: "\\n\\n")
  - `:format` - Output format (default: :text)
  """
  @type options :: [
          capitalize_sentences: boolean(),
          add_punctuation: boolean(),
          paragraph_separator: String.t(),
          format: :text | :markdown | :html
        ]

  @doc """
  Renders an AST node to text.

  ## Examples

      iex> Nasty.Rendering.Text.render(document)
      {:ok, "The cat sat on the mat."}

      iex> Nasty.Rendering.Text.render(document, capitalize_sentences: false)
      {:ok, "the cat sat on the mat."}
  """
  @spec render(term(), options()) :: {:ok, String.t()} | {:error, term()}
  def render(node, opts \\ [])

  def render(%Document{} = doc, opts) do
    para_sep = Keyword.get(opts, :paragraph_separator, "\n\n")

    texts =
      Enum.map(doc.paragraphs, fn para ->
        case render(para, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)

    {:ok, Enum.join(texts, para_sep)}
  end

  def render(%Paragraph{} = para, opts) do
    texts =
      Enum.map(para.sentences, fn sent ->
        case render(sent, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)

    {:ok, Enum.join(texts, " ")}
  end

  def render(%Sentence{} = sent, opts) do
    capitalize? = Keyword.get(opts, :capitalize_sentences, true)
    add_punct? = Keyword.get(opts, :add_punctuation, true)

    # Render main clause
    with {:ok, main_text} <- render(sent.main_clause, opts) do
      # Render additional clauses
      additional_texts =
        Enum.map(sent.additional_clauses, fn clause ->
          case render(clause, opts) do
            {:ok, text} -> text
            {:error, _} -> ""
          end
        end)

      # Join all clauses
      full_text =
        [main_text | additional_texts]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(" ")

      # Apply capitalization
      full_text =
        if capitalize? do
          String.capitalize(full_text)
        else
          full_text
        end

      # Add sentence-ending punctuation if needed
      full_text =
        if add_punct? and not String.ends_with?(full_text, [".", "!", "?"]) do
          case sent.function do
            :interrogative -> full_text <> "?"
            :exclamative -> full_text <> "!"
            _ -> full_text <> "."
          end
        else
          full_text
        end

      {:ok, full_text}
    end
  end

  def render(%Clause{} = clause, opts) do
    parts = []

    # Add subordinator if present
    parts =
      if clause.subordinator do
        case render(clause.subordinator, opts) do
          {:ok, text} -> [text | parts]
          {:error, _} -> parts
        end
      else
        parts
      end

    # Add subject if present
    parts =
      if clause.subject do
        case render(clause.subject, opts) do
          {:ok, text} -> parts ++ [text]
          {:error, _} -> parts
        end
      else
        parts
      end

    # Add predicate (verb phrase)
    parts =
      case render(clause.predicate, opts) do
        {:ok, text} -> parts ++ [text]
        {:error, _} -> parts
      end

    {:ok, Enum.join(parts, " ")}
  end

  def render(%NounPhrase{} = np, opts) do
    parts = []

    # Determiner
    parts =
      if np.determiner do
        case render(np.determiner, opts) do
          {:ok, text} -> [text | parts]
          {:error, _} -> parts
        end
      else
        parts
      end

    # Modifiers (adjectives)
    modifier_texts =
      Enum.map(np.modifiers, fn mod ->
        case render(mod, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))

    parts = parts ++ modifier_texts

    # Head noun
    parts =
      case render(np.head, opts) do
        {:ok, text} -> parts ++ [text]
        {:error, _} -> parts
      end

    # Post-modifiers (PPs, relative clauses)
    postmod_texts =
      Enum.map(np.post_modifiers, fn mod ->
        case render(mod, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))

    parts = parts ++ postmod_texts

    {:ok, Enum.join(parts, " ")}
  end

  def render(%VerbPhrase{} = vp, opts) do
    parts = []

    # Auxiliaries
    aux_texts =
      Enum.map(vp.auxiliaries, fn aux ->
        case render(aux, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))

    parts = parts ++ aux_texts

    # Main verb
    parts =
      case render(vp.head, opts) do
        {:ok, text} -> parts ++ [text]
        {:error, _} -> parts
      end

    # Complements (objects, clausal complements)
    comp_texts =
      Enum.map(vp.complements, fn comp ->
        case render(comp, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))

    parts = parts ++ comp_texts

    # Adverbials
    adv_texts =
      Enum.map(vp.adverbials, fn adv ->
        case render(adv, opts) do
          {:ok, text} -> text
          {:error, _} -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))

    parts = parts ++ adv_texts

    {:ok, Enum.join(parts, " ")}
  end

  def render(%PrepositionalPhrase{} = pp, opts) do
    with {:ok, prep_text} <- render(pp.head, opts),
         {:ok, obj_text} <- render(pp.object, opts) do
      {:ok, prep_text <> " " <> obj_text}
    end
  end

  def render(%AdjectivalPhrase{} = ap, opts) do
    parts = []

    # Intensifier
    parts =
      if ap.intensifier do
        case render(ap.intensifier, opts) do
          {:ok, text} -> [text | parts]
          {:error, _} -> parts
        end
      else
        parts
      end

    # Head adjective
    parts =
      case render(ap.head, opts) do
        {:ok, text} -> parts ++ [text]
        {:error, _} -> parts
      end

    # Complement
    parts =
      if ap.complement do
        case render(ap.complement, opts) do
          {:ok, text} -> parts ++ [text]
          {:error, _} -> parts
        end
      else
        parts
      end

    {:ok, Enum.join(parts, " ")}
  end

  def render(%AdverbialPhrase{} = advp, opts) do
    parts = []

    # Intensifier
    parts =
      if advp.intensifier do
        case render(advp.intensifier, opts) do
          {:ok, text} -> [text | parts]
          {:error, _} -> parts
        end
      else
        parts
      end

    # Head adverb
    parts =
      case render(advp.head, opts) do
        {:ok, text} -> parts ++ [text]
        {:error, _} -> parts
      end

    {:ok, Enum.join(parts, " ")}
  end

  def render(%Token{} = token, _opts) do
    {:ok, token.text}
  end

  def render(node, _opts) do
    {:error, {:unsupported_node_type, node}}
  end

  @doc """
  Renders an AST node to text, raising on error.

  ## Examples

      iex> Nasty.Rendering.Text.render!(document)
      "The cat sat on the mat."
  """
  @spec render!(term(), options()) :: String.t()
  def render!(node, opts \\ []) do
    case render(node, opts) do
      {:ok, text} -> text
      {:error, reason} -> raise "Rendering failed: #{inspect(reason)}"
    end
  end

  @doc """
  Applies subject-verb agreement rules for English.

  This is a helper for generating text with correct agreement.

  ## Examples

      iex> Nasty.Rendering.Text.apply_agreement("cat", "run", :en)
      {"cat", "runs"}

      iex> Nasty.Rendering.Text.apply_agreement("cats", "run", :en)
      {"cats", "run"}
  """
  @spec apply_agreement(String.t(), String.t(), atom()) :: {String.t(), String.t()}
  def apply_agreement(subject, verb, language)

  def apply_agreement(subject, verb, :en) do
    # Simple English agreement: if subject is singular, add -s to verb
    # This is a simplified version; full implementation would need morphology
    singular? = not String.ends_with?(subject, "s")

    verb =
      if singular? and not String.ends_with?(verb, "s") do
        verb <> "s"
      else
        verb
      end

    {subject, verb}
  end

  def apply_agreement(subject, verb, _language) do
    # Default: no change
    {subject, verb}
  end
end
