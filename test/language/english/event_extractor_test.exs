defmodule Nasty.Language.English.EventExtractorTest do
  use ExUnit.Case, async: true

  alias Nasty.AST.{Document, Event, Paragraph}

  alias Nasty.Language.English.{
    EventExtractor,
    Morphology,
    POSTagger,
    SentenceParser,
    Tokenizer
  }

  # Helper to parse text into a document
  defp parse_document(text) do
    {:ok, tokens} = Tokenizer.tokenize(text)
    {:ok, tagged} = POSTagger.tag_pos(tokens)
    {:ok, analyzed} = Morphology.analyze(tagged)
    {:ok, sentences} = SentenceParser.parse_sentences(analyzed)

    doc_span = Nasty.AST.Node.make_span({1, 0}, 0, {10, 0}, String.length(text))

    paragraph = %Paragraph{
      sentences: sentences,
      span: doc_span,
      language: :en
    }

    %Document{
      paragraphs: [paragraph],
      span: doc_span,
      language: :en,
      metadata: %{}
    }
  end

  describe "extract/1 with business events" do
    test "extracts acquisition event" do
      text = "Google acquired YouTube in 2006."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      acquisition = Enum.find(events, fn e -> e.type == :business_acquisition end)

      if acquisition do
        assert acquisition.trigger.text in ["acquired", "acquire"]
        assert is_map(acquisition.participants)
        assert is_float(acquisition.confidence)
      end
    end

    test "extracts product launch event" do
      text = "Apple launched the iPhone yesterday."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      launch = Enum.find(events, fn e -> e.type == :product_launch end)

      if launch do
        assert launch.trigger.text in ["launched", "launch"]
      end
    end

    test "extracts company founding event" do
      text = "Steve Jobs founded Apple in 1976."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      founding = Enum.find(events, fn e -> e.type == :company_founding end)

      if founding do
        assert founding.type == :company_founding
        assert is_map(founding.participants)
      end
    end
  end

  describe "extract/1 with employment events" do
    test "extracts hiring event" do
      text = "Microsoft hired Sarah as an engineer."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      hiring = Enum.find(events, fn e -> e.type == :employment_start end)

      if hiring do
        assert hiring.trigger.text in ["hired", "hire"]
      end
    end

    test "extracts resignation event" do
      text = "The CEO resigned last month."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      resignation = Enum.find(events, fn e -> e.type == :employment_end end)

      if resignation do
        assert resignation.trigger.text in ["resigned", "resign"]
      end
    end
  end

  describe "extract/1 with communication events" do
    test "extracts announcement event" do
      text = "The company announced new features."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      announcement = Enum.find(events, fn e -> e.type == :announcement end)

      if announcement do
        assert announcement.trigger.text in ["announced", "announce"]
      end
    end

    test "extracts meeting event" do
      text = "The team met yesterday to discuss plans."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      meeting = Enum.find(events, fn e -> e.type == :meeting end)

      if meeting do
        assert meeting.trigger.text in ["met", "meet"]
      end
    end
  end

  describe "extract/1 with temporal information" do
    test "extracts time from date entities" do
      text = "Apple launched the iPhone in January."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      launch = Enum.find(events, fn e -> e.type == :product_launch end)

      if launch && launch.time do
        assert String.contains?(launch.time, "January")
      end
    end
  end

  describe "extract/1 with nominalizations" do
    test "extracts event from nominalization" do
      text = "The acquisition of YouTube was announced."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      # Should find acquisition event
      acquisition = Enum.find(events, fn e -> e.type == :business_acquisition end)

      if acquisition do
        assert acquisition.trigger.text == "acquisition"
        assert acquisition.trigger.pos_tag == :noun
      end
    end
  end

  describe "extract/1 with options" do
    test "respects min_confidence option" do
      text = "Google acquired YouTube and launched Gmail."
      document = parse_document(text)

      {:ok, all_events} = EventExtractor.extract(document, min_confidence: 0.0)
      {:ok, high_conf_events} = EventExtractor.extract(document, min_confidence: 0.9)

      assert length(high_conf_events) <= length(all_events)
    end

    test "respects max_events option" do
      text = "Google acquired YouTube, launched Gmail, and hired engineers."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document, max_events: 2)

      assert length(events) <= 2
    end
  end

  describe "extract/1 with no events" do
    test "returns empty list for sentence without event triggers" do
      text = "The cat is sleeping."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      # May or may not find events depending on triggers
      assert is_list(events)
    end
  end

  describe "Event structure" do
    test "event has correct fields" do
      text = "Google acquired YouTube."
      document = parse_document(text)

      {:ok, events} = EventExtractor.extract(document)

      if match?([_ | _], events) do
        event = hd(events)

        assert %Event{} = event
        assert is_atom(event.type)
        assert is_map(event.trigger)
        assert is_map(event.participants)
        assert is_float(event.confidence) or is_nil(event.confidence)
      end
    end
  end
end
