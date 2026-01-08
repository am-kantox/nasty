defmodule Mix.Tasks.Nasty.Wordnet.List do
  @moduledoc """
  Lists installed WordNet data files and their status.

  ## Usage

      mix nasty.wordnet.list

  ## Output

  Shows for each language:
  - Installation status
  - File path
  - File size
  - Load status (loaded in memory or not)
  - Statistics if loaded (synset/lemma/relation counts)
  """

  use Mix.Task

  alias Nasty.Lexical.WordNet

  @shortdoc "Lists installed WordNet data files"

  @default_wordnet_dir "priv/wordnet"

  @impl Mix.Task
  def run(_args) do
    # Start application to access WordNet API
    Mix.Task.run("app.start")

    Mix.shell().info("WordNet Data Status")
    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("")

    languages = [:en, :es, :ca]

    for language <- languages do
      show_language_status(language)
      Mix.shell().info("")
    end

    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("")
    Mix.shell().info("To download WordNet data:")
    Mix.shell().info("  mix nasty.wordnet.download --language <lang>")
  end

  defp show_language_status(language) do
    lang_name = language_name(language)
    file_path = wordnet_file_path(language)

    Mix.shell().info("#{lang_name} (#{language})")

    if File.exists?(file_path) do
      file_size = file_size_mb(file_path)
      Mix.shell().info("  Status: Installed")
      Mix.shell().info("  Path: #{file_path}")
      Mix.shell().info("  Size: #{file_size} MB")

      # Check if loaded in memory
      if WordNet.loaded?(language) do
        Mix.shell().info("  Loaded: Yes")

        stats = WordNet.stats(language)
        Mix.shell().info("  Synsets: #{format_number(stats.synsets)}")
        Mix.shell().info("  Lemmas: #{format_number(stats.lemmas)}")
        Mix.shell().info("  Relations: #{format_number(stats.relations)}")
      else
        Mix.shell().info("  Loaded: No (will load on first use)")
      end
    else
      Mix.shell().info("  Status: Not installed")
      Mix.shell().info("  Download: mix nasty.wordnet.download --language #{language}")
    end
  end

  defp language_name(language) do
    case language do
      :en -> "English"
      :es -> "Spanish"
      :ca -> "Catalan"
      _ -> to_string(language)
    end
  end

  defp wordnet_file_path(language) do
    filename =
      case language do
        :en -> "oewn-2025.json"
        :es -> "omw-es.json"
        :ca -> "omw-ca.json"
        _ -> "omw-#{language}.json"
      end

    Path.join(@default_wordnet_dir, filename)
  end

  defp file_size_mb(path) do
    case File.stat(path) do
      {:ok, %{size: size}} ->
        Float.round(size / 1_048_576, 2)

      _ ->
        0
    end
  end

  defp format_number(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
