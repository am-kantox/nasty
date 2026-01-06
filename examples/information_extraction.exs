#!/usr/bin/env elixir

# Information Extraction Examples
# Demonstrates relation extraction, event extraction, and template-based extraction

Mix.install([{:nasty, path: Path.expand("..", __DIR__)}])

alias Nasty.Language.English
alias Nasty.Language.English.TemplateExtractor

defmodule InformationExtractionExamples do
  @moduledoc """
  Examples demonstrating information extraction capabilities.
  """

  def run do
    IO.puts("\n=== Information Extraction Examples ===\n")

    relation_extraction()
    IO.puts("\n" <> String.duplicate("-", 60) <> "\n")

    event_extraction()
    IO.puts("\n" <> String.duplicate("-", 60) <> "\n")

    template_extraction()
    IO.puts("\n" <> String.duplicate("-", 60) <> "\n")

    combined_extraction()
  end

  defp relation_extraction do
    IO.puts("1. RELATION EXTRACTION")
    IO.puts("=" <> String.duplicate("=", 58))

    texts = [
      "John Smith works at Google in Mountain View, California.",
      "Steve Jobs founded Apple in 1976.",
      "Microsoft acquired LinkedIn for 26.2 billion dollars.",
      "Tim Cook is the CEO of Apple.",
      "Amazon is headquartered in Seattle, Washington."
    ]

    IO.puts("\nExtracting relations from news sentences:")

    for text <- texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      {:ok, relations} = English.extract_relations(document)

      IO.puts("\nText: \"#{text}\"")

      if Enum.empty?(relations) do
        IO.puts("  No relations found")
      else
        IO.puts("  Relations found:")

        for relation <- relations do
          subject = relation_subject(relation)
          object = relation_object(relation)
          type = relation.type
          confidence = Float.round(relation.confidence * 100, 1)

          IO.puts("    - #{subject} #{type} #{object} (#{confidence}%)")
        end
      end
    end
  end

  defp event_extraction do
    IO.puts("2. EVENT EXTRACTION")
    IO.puts("=" <> String.duplicate("=", 58))

    texts = [
      "Google acquired YouTube in October 2006 for 1.65 billion dollars.",
      "Apple launched the iPhone on January 9, 2007.",
      "Microsoft and Nokia announced a partnership yesterday.",
      "The team met to discuss the new product strategy.",
      "Tesla started production of the Model 3 in July 2017."
    ]

    IO.puts("\nExtracting events from news sentences:")

    for text <- texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      {:ok, events} = English.extract_events(document)

      IO.puts("\nText: \"#{text}\"")

      if Enum.empty?(events) do
        IO.puts("  No events found")
      else
        IO.puts("  Events found:")

        for event <- events do
          trigger = event_trigger(event)
          type = event.type
          confidence = Float.round(event.confidence * 100, 1)
          time_str = if event.time, do: " [#{event.time}]", else: ""

          IO.puts("    - Event: #{type}")
          IO.puts("      Trigger: #{trigger}")

          unless Enum.empty?(event.participants) do
            IO.puts("      Participants:")

            for {role, participant} <- event.participants do
              participant_text = participant_to_text(participant)
              IO.puts("        #{role}: #{participant_text}")
            end
          end

          IO.puts("      Confidence: #{confidence}%#{time_str}")
        end
      end
    end
  end

  defp template_extraction do
    IO.puts("3. TEMPLATE-BASED EXTRACTION")
    IO.puts("=" <> String.duplicate("=", 58))

    IO.puts("\nUsing predefined templates for structured extraction:")

    # Employment template example
    IO.puts("\n--- Employment Template ---")
    employment_texts = [
      "Sarah Johnson works at Microsoft.",
      "Bob Williams joined Amazon as a senior engineer.",
      "Alice Chen was hired by Google."
    ]

    employment_template = TemplateExtractor.employment_template()

    for text <- employment_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      {:ok, results} = English.extract_templates(document, [employment_template])

      IO.puts("\nText: \"#{text}\"")

      if Enum.empty?(results) do
        IO.puts("  No matches")
      else
        result = hd(results)
        confidence = Float.round(result.confidence * 100, 1)
        IO.puts("  Template: #{result.template}")
        IO.puts("  Slots:")

        for {slot, value} <- result.slots do
          IO.puts("    #{slot}: #{value}")
        end

        IO.puts("  Confidence: #{confidence}%")
      end
    end

    # Acquisition template example
    IO.puts("\n--- Acquisition Template ---")
    acquisition_texts = [
      "Facebook acquired Instagram in 2012.",
      "Oracle bought Sun Microsystems.",
      "Disney purchased Pixar Animation Studios."
    ]

    acquisition_template = TemplateExtractor.acquisition_template()

    for text <- acquisition_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      {:ok, results} = English.extract_templates(document, [acquisition_template])

      IO.puts("\nText: \"#{text}\"")

      if Enum.empty?(results) do
        IO.puts("  No matches")
      else
        result = hd(results)
        confidence = Float.round(result.confidence * 100, 1)
        IO.puts("  Template: #{result.template}")
        IO.puts("  Slots:")

        for {slot, value} <- result.slots do
          IO.puts("    #{slot}: #{value}")
        end

        IO.puts("  Confidence: #{confidence}%")
      end
    end

    # Location template example
    IO.puts("\n--- Location Template ---")
    location_texts = [
      "Apple is based in Cupertino, California.",
      "Microsoft is headquartered in Redmond, Washington.",
      "Amazon is located in Seattle."
    ]

    location_template = TemplateExtractor.location_template()

    for text <- location_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, document} = English.parse(tagged)

      {:ok, results} = English.extract_templates(document, [location_template])

      IO.puts("\nText: \"#{text}\"")

      if Enum.empty?(results) do
        IO.puts("  No matches")
      else
        result = hd(results)
        confidence = Float.round(result.confidence * 100, 1)
        IO.puts("  Template: #{result.template}")
        IO.puts("  Slots:")

        for {slot, value} <- result.slots do
          IO.puts("    #{slot}: #{value}")
        end

        IO.puts("  Confidence: #{confidence}%")
      end
    end
  end

  defp combined_extraction do
    IO.puts("4. COMBINED EXTRACTION")
    IO.puts("=" <> String.duplicate("=", 58))

    text = """
    John Smith works at Google in Mountain View, California.
    Google acquired YouTube in October 2006 for 1.65 billion dollars.
    The company launched Gmail in 2004.
    Sundar Pichai became CEO of Google in 2015.
    """

    IO.puts("\nExtracting all information types from a multi-sentence text:")
    IO.puts("\nOriginal Text:")
    IO.puts(text)

    {:ok, tokens} = English.tokenize(text)
    {:ok, tagged} = English.tag_pos(tokens)
    {:ok, document} = English.parse(tagged)

    # Extract relations
    {:ok, relations} = English.extract_relations(document)

    IO.puts("\n--- Relations (#{length(relations)}) ---")

    for relation <- Enum.take(relations, 5) do
      subject = relation_subject(relation)
      object = relation_object(relation)
      confidence = Float.round(relation.confidence * 100, 1)
      IO.puts("  #{subject} #{relation.type} #{object} (#{confidence}%)")
    end

    # Extract events
    {:ok, events} = English.extract_events(document)

    IO.puts("\n--- Events (#{length(events)}) ---")

    for event <- Enum.take(events, 5) do
      trigger = event_trigger(event)
      confidence = Float.round(event.confidence * 100, 1)
      IO.puts("  #{event.type}: #{trigger} (#{confidence}%)")
    end

    # Extract using multiple templates
    templates = [
      TemplateExtractor.employment_template(),
      TemplateExtractor.acquisition_template(),
      TemplateExtractor.location_template()
    ]

    {:ok, template_results} = English.extract_templates(document, templates)

    IO.puts("\n--- Template Matches (#{length(template_results)}) ---")

    for result <- Enum.take(template_results, 5) do
      confidence = Float.round(result.confidence * 100, 1)
      slots_str = result.slots |> Enum.map(fn {k, v} -> "#{k}:#{v}" end) |> Enum.join(", ")
      IO.puts("  #{result.template}: #{slots_str} (#{confidence}%)")
    end

    IO.puts("\nTotal extracted:")
    IO.puts("  Relations: #{length(relations)}")
    IO.puts("  Events: #{length(events)}")
    IO.puts("  Template matches: #{length(template_results)}")
  end

  # Helper functions
  defp relation_subject(relation) do
    case relation.subject do
      %{text: text} -> text
      text when is_binary(text) -> text
      _ -> "?"
    end
  end

  defp relation_object(relation) do
    case relation.object do
      %{text: text} -> text
      text when is_binary(text) -> text
      _ -> "?"
    end
  end

  defp event_trigger(event) do
    case event.trigger do
      %{text: text} -> text
      %{lemma: lemma} when is_binary(lemma) -> lemma
      text when is_binary(text) -> text
      _ -> "?"
    end
  end

  defp participant_to_text(participant) do
    case participant do
      %{text: text} -> text
      text when is_binary(text) -> text
      _ -> "?"
    end
  end
end

InformationExtractionExamples.run()
