# Text Classification Examples
# Demonstrates sentiment analysis, spam detection, and topic classification
# Run with: mix run examples/text_classification.exs

alias Nasty.Language.English

defmodule ClassificationExamples do
  @moduledoc """
  Examples demonstrating text classification capabilities.
  """

  def run do
    IO.puts("\n=== Text Classification Examples ===\n")

    sentiment_analysis()
    IO.puts("\n" <> String.duplicate("-", 60) <> "\n")

    spam_detection()
    IO.puts("\n" <> String.duplicate("-", 60) <> "\n")

    topic_classification()
    IO.puts("\n" <> String.duplicate("-", 60) <> "\n")

    multi_feature_classification()
  end

  defp sentiment_analysis do
    IO.puts("1. SENTIMENT ANALYSIS")
    IO.puts("=" <> String.duplicate("=", 58))

    # Training data with positive and negative reviews
    training_texts = [
      {"This product is absolutely fantastic and amazing", :positive},
      {"I love it so much, best purchase ever", :positive},
      {"Excellent quality, highly recommended", :positive},
      {"Great value for money, very satisfied", :positive},
      {"Outstanding performance, exceeded expectations", :positive},
      {"Terrible quality, complete waste of money", :negative},
      {"Worst product ever, very disappointed", :negative},
      {"Poor design, broke after one day", :negative},
      {"Horrible experience, would not recommend", :negative},
      {"Awful service, extremely frustrating", :negative}
    ]

    IO.puts("\nTraining sentiment classifier...")
    training_data =
      Enum.map(training_texts, fn {text, label} ->
        {:ok, tokens} = English.tokenize(text)
        {:ok, tagged} = English.tag_pos(tokens)
        {:ok, doc} = English.parse(tagged)
        {doc, label}
      end)

    model = English.train_classifier(training_data, features: [:bow])
    IO.puts("Model trained with #{length(training_data)} examples")

    # Test on new reviews
    test_texts = [
      "Amazing quality, I really like this product",
      "Very disappointing, not worth the price",
      "Good but could be better",
      "Absolutely terrible, avoid at all costs"
    ]

    IO.puts("\nClassifying test reviews:")
    for text <- test_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, doc} = English.parse(tagged)

      {:ok, [top | _rest]} = English.classify(doc, model)

      sentiment = format_sentiment(top.class)
      confidence = Float.round(top.confidence * 100, 1)

      IO.puts("\nText: \"#{text}\"")
      IO.puts("  Sentiment: #{sentiment}")
      IO.puts("  Confidence: #{confidence}%")
    end
  end

  defp spam_detection do
    IO.puts("2. SPAM DETECTION")
    IO.puts("=" <> String.duplicate("=", 58))

    # Training data for spam vs legitimate messages
    training_texts = [
      {"Congratulations! You won a million dollars! Click here now!", :spam},
      {"Free money! Act now! Limited time offer!", :spam},
      {"Win prizes! Click this link immediately!", :spam},
      {"You have been selected for a special prize!", :spam},
      {"Get rich quick! Guaranteed returns!", :spam},
      {"Meeting scheduled for tomorrow at 3pm in conference room", :ham},
      {"Please review the attached quarterly report", :ham},
      {"Reminder: Team lunch on Friday", :ham},
      {"Could you send me the latest project update?", :ham},
      {"Thanks for your help with the presentation yesterday", :ham}
    ]

    IO.puts("\nTraining spam detector...")
    training_data =
      Enum.map(training_texts, fn {text, label} ->
        {:ok, tokens} = English.tokenize(text)
        {:ok, tagged} = English.tag_pos(tokens)
        {:ok, doc} = English.parse(tagged)
        {doc, label}
      end)

    model = English.train_classifier(training_data, features: [:bow, :lexical])
    IO.puts("Model trained with #{length(training_data)} examples")

    # Test on new messages
    test_texts = [
      "Free vacation! Click now to claim your prize!",
      "Can we reschedule our meeting to next week?",
      "You won the lottery! Send your details immediately!",
      "Please find attached the invoice for last month"
    ]

    IO.puts("\nClassifying test messages:")
    for text <- test_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, doc} = English.parse(tagged)

      {:ok, [top | _rest]} = English.classify(doc, model)

      classification = format_spam(top.class)
      confidence = Float.round(top.confidence * 100, 1)

      IO.puts("\nText: \"#{text}\"")
      IO.puts("  Classification: #{classification}")
      IO.puts("  Confidence: #{confidence}%")
    end
  end

  defp topic_classification do
    IO.puts("3. TOPIC CLASSIFICATION")
    IO.puts("=" <> String.duplicate("=", 58))

    # Training data for different topics
    training_texts = [
      {"The team scored three goals in the final match", :sports},
      {"Championship victory celebrated by fans worldwide", :sports},
      {"Athletes compete for gold medal at Olympics", :sports},
      {"Machine learning algorithms improve accuracy", :technology},
      {"New smartphone features advanced AI capabilities", :technology},
      {"Software update brings enhanced security features", :technology},
      {"Government announces new policy on healthcare", :politics},
      {"Election results show close race between candidates", :politics},
      {"Parliament debates proposed legislation", :politics},
      {"Stock market reaches all-time high", :business},
      {"Company reports record quarterly earnings", :business},
      {"Merger between major corporations announced", :business}
    ]

    IO.puts("\nTraining topic classifier...")
    training_data =
      Enum.map(training_texts, fn {text, label} ->
        {:ok, tokens} = English.tokenize(text)
        {:ok, tagged} = English.tag_pos(tokens)
        {:ok, doc} = English.parse(tagged)
        {doc, label}
      end)

    model = English.train_classifier(training_data, features: [:bow, :entities])
    IO.puts("Model trained with #{length(training_data)} examples")

    # Test on new articles
    test_texts = [
      "Football team wins championship after dramatic penalty shootout",
      "New artificial intelligence system demonstrates impressive capabilities",
      "Presidential debate focuses on economic policy and healthcare reform",
      "Tech startup valued at billion dollars after latest funding round"
    ]

    IO.puts("\nClassifying test articles:")
    for text <- test_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, doc} = English.parse(tagged)

      {:ok, predictions} = English.classify(doc, model)

      IO.puts("\nText: \"#{text}\"")
      IO.puts("  Top predictions:")

      predictions
      |> Enum.take(2)
      |> Enum.each(fn pred ->
        confidence = Float.round(pred.confidence * 100, 1)
        IO.puts("    - #{format_topic(pred.class)}: #{confidence}%")
      end)
    end
  end

  defp multi_feature_classification do
    IO.puts("4. MULTI-FEATURE CLASSIFICATION")
    IO.puts("=" <> String.duplicate("=", 58))

    IO.puts("\nDemonstrating classification with multiple feature types:")

    # Training data distinguishing formal vs informal text
    training_texts = [
      {"Hey what's up dude how r u doing lol", :informal},
      {"gonna go out later wanna come", :informal},
      {"thx so much ur the best", :informal},
      {"Dear Sir, I am writing to inform you of the matter", :formal},
      {"Please find attached the requested documentation", :formal},
      {"We would appreciate your prompt response to this inquiry", :formal}
    ]

    IO.puts("\nTraining formality classifier with multiple features...")
    training_data =
      Enum.map(training_texts, fn {text, label} ->
        {:ok, tokens} = English.tokenize(text)
        {:ok, tagged} = English.tag_pos(tokens)
        {:ok, doc} = English.parse(tagged)
        {doc, label}
      end)

    # Use multiple feature types for better discrimination
    model = English.train_classifier(training_data, features: [:bow, :lexical, :pos_patterns])
    IO.puts("Model trained with features: bag-of-words, lexical, POS patterns")

    test_texts = [
      "Thanks a lot really appreciate it",
      "I would be grateful if you could provide assistance"
    ]

    IO.puts("\nClassifying test messages:")
    for text <- test_texts do
      {:ok, tokens} = English.tokenize(text)
      {:ok, tagged} = English.tag_pos(tokens)
      {:ok, doc} = English.parse(tagged)

      {:ok, [top | _rest]} = English.classify(doc, model)

      confidence = Float.round(top.confidence * 100, 1)

      IO.puts("\nText: \"#{text}\"")
      IO.puts("  Style: #{format_formality(top.class)}")
      IO.puts("  Confidence: #{confidence}%")
    end
  end

  # Helper formatting functions
  defp format_sentiment(:positive), do: "Positive"
  defp format_sentiment(:negative), do: "Negative"

  defp format_spam(:spam), do: "SPAM"
  defp format_spam(:ham), do: "Legitimate"

  defp format_topic(:sports), do: "Sports"
  defp format_topic(:technology), do: "Technology"
  defp format_topic(:politics), do: "Politics"
  defp format_topic(:business), do: "Business"

  defp format_formality(:formal), do: "Formal"
  defp format_formality(:informal), do: "Informal"
end

ClassificationExamples.run()
