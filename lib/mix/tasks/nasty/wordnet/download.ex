defmodule Mix.Tasks.Nasty.Wordnet.Download do
  @moduledoc """
  Downloads WordNet data files from official sources.

  ## Usage

      # Download English WordNet
      mix nasty.wordnet.download --language en

      # Download Spanish WordNet
      mix nasty.wordnet.download --language es

      # Download specific version
      mix nasty.wordnet.download --language en --version 2025

      # Download to custom directory
      mix nasty.wordnet.download --language en --output /custom/path

  ## Available Languages

  - `en` - English (Open English WordNet)
  - `es` - Spanish (Open Multilingual WordNet)
  - `ca` - Catalan (Open Multilingual WordNet)

  ## Data Sources

  - English: https://github.com/globalwordnet/english-wordnet/releases
  - Multilingual: https://github.com/omwn/omw-data
  """

  use Mix.Task

  @shortdoc "Downloads WordNet data files"

  @default_output_dir "priv/wordnet"

  @download_urls %{
    en: "https://en-word.net/static/english-wordnet-2025.xml",
    es: "https://github.com/omwn/omw-data/raw/master/wns/omw-es31.xml",
    ca: "https://github.com/omwn/omw-data/raw/master/wns/omw-ca.xml"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        strict: [
          language: :string,
          version: :string,
          output: :string,
          force: :boolean
        ],
        aliases: [l: :language, v: :version, o: :output, f: :force]
      )

    language = parse_language(opts[:language])
    output_dir = opts[:output] || @default_output_dir
    force = opts[:force] || false

    case language do
      nil ->
        Mix.shell().error("Error: --language option is required")
        Mix.shell().info("Available languages: en, es, ca")
        Mix.shell().info("Example: mix nasty.wordnet.download --language en")

      lang ->
        download_wordnet(lang, output_dir, force)
    end
  end

  defp parse_language(nil), do: nil

  defp parse_language(lang_string) do
    case String.downcase(lang_string) do
      "en" -> :en
      "english" -> :en
      "es" -> :es
      "spanish" -> :es
      "ca" -> :ca
      "catalan" -> :ca
      _ -> nil
    end
  end

  defp download_wordnet(language, output_dir, force) do
    output_file = Path.join(output_dir, filename_for(language))

    if File.exists?(output_file) && !force do
      Mix.shell().info("WordNet data already exists at: #{output_file}")
      Mix.shell().info("Use --force to redownload")
      :ok
    else
      Mix.shell().info("Downloading WordNet data for #{language}...")

      # Create output directory if needed
      File.mkdir_p!(output_dir)

      url = @download_urls[language]

      if url do
        case download_file(url, output_file) do
          :ok ->
            Mix.shell().info("Successfully downloaded WordNet to: #{output_file}")
            Mix.shell().info("File size: #{file_size_mb(output_file)} MB")
            :ok

          {:error, reason} ->
            Mix.shell().error("Failed to download: #{inspect(reason)}")
            {:error, reason}
        end
      else
        Mix.shell().error("No download URL configured for language: #{language}")
        {:error, :no_url}
      end
    end
  end

  defp filename_for(language) do
    case language do
      :en -> "oewn-2025.json"
      :es -> "omw-es.json"
      :ca -> "omw-ca.json"
      _ -> "omw-#{language}.json"
    end
  end

  defp download_file(url, output_path) do
    # Start :inets and :ssl applications
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    Mix.shell().info("Downloading from: #{url}")
    Mix.shell().info("This may take a few minutes...")

    url_charlist = String.to_charlist(url)

    # HTTP request with redirect following
    case :httpc.request(:get, {url_charlist, []}, [{:autoredirect, true}], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        File.write!(output_path, body)
        :ok

      {:ok, {{_, status_code, _}, _headers, _body}} ->
        {:error, {:http_error, status_code}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      {:error, e}
  end

  defp file_size_mb(path) do
    case File.stat(path) do
      {:ok, %{size: size}} ->
        Float.round(size / 1_048_576, 2)

      _ ->
        0
    end
  end
end
