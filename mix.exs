defmodule Nasty.MixProject do
  use Mix.Project

  @app :nasty
  @version "0.3.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Nasty",
      source_url: "https://github.com/am-kantox/#{@app}",
      # Test coverage
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp description do
    """
    A language-agnostic NLP library for Elixir that treats natural language
    with the same rigor as programming languages. Provides a comprehensive AST
    for natural languages, enabling parsing, analysis, and bidirectional code conversion.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|lib docs stuff/img .formatter.exs mix.exs README* LICENSE|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/am-kantox/#{@app}"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/img/logo-96x96.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      extras: [
        "README.md",
        # Getting Started
        "docs/GETTING_STARTED.md",
        "docs/USER_GUIDE.md",
        "docs/STRENGTHS_AND_LIMITATIONS.md",
        "docs/EXAMPLES.md",
        # Core Documentation
        "docs/ARCHITECTURE.md",
        "docs/API.md",
        "docs/AST_REFERENCE.md",
        "docs/PARSING_GUIDE.md",
        # Language Support
        "docs/LANGUAGE_GUIDE.md",
        "docs/languages/ENGLISH_GRAMMAR.md",
        "docs/languages/SPANISH_GRAMMAR.md",
        "docs/languages/CATALAN.md",
        "docs/CROSS_LINGUAL.md",
        "docs/TRANSLATION.md",
        # Advanced Features
        "docs/GRAMMAR_CUSTOMIZATION.md",
        "docs/GRAMMAR_RESOURCES.md",
        "docs/INFORMATION_EXTRACTION.md",
        "docs/E2E_COREFERENCE.md",
        "docs/WORDNET.md",
        # Code Interoperability
        "docs/INTEROP_GUIDE.md",
        # Models and Training
        "docs/STATISTICAL_MODELS.md",
        "docs/NEURAL_MODELS.md",
        "docs/NEURAL_COREFERENCE.md",
        "docs/TRAINING_NEURAL.md",
        "docs/FINE_TUNING.md",
        "docs/PRETRAINED_MODELS.md",
        "docs/ZERO_SHOT.md",
        "docs/QUANTIZATION.md",
        # Performance and Best Practices
        "docs/PERFORMANCE.md",
        "docs/REFACTORING.md"
      ],
      groups_for_extras: [
        "Getting Started": [
          "docs/GETTING_STARTED.md",
          "docs/STRENGTHS_AND_LIMITATIONS.md",
          "docs/USER_GUIDE.md",
          "docs/EXAMPLES.md"
        ],
        "Core Documentation": [
          "docs/ARCHITECTURE.md",
          "docs/API.md",
          "docs/AST_REFERENCE.md",
          "docs/PARSING_GUIDE.md"
        ],
        "Language Support": [
          "docs/LANGUAGE_GUIDE.md",
          "docs/languages/ENGLISH_GRAMMAR.md",
          "docs/languages/SPANISH_GRAMMAR.md",
          "docs/languages/CATALAN.md",
          "docs/CROSS_LINGUAL.md",
          "docs/TRANSLATION.md"
        ],
        "Advanced Features": [
          "docs/GRAMMAR_CUSTOMIZATION.md",
          "docs/GRAMMAR_RESOURCES.md",
          "docs/INFORMATION_EXTRACTION.md",
          "docs/E2E_COREFERENCE.md",
          "docs/WORDNET.md"
        ],
        "Code Interoperability": [
          "docs/INTEROP_GUIDE.md"
        ],
        "Models and Training": [
          "docs/STATISTICAL_MODELS.md",
          "docs/NEURAL_MODELS.md",
          "docs/NEURAL_COREFERENCE.md",
          "docs/TRAINING_NEURAL.md",
          "docs/FINE_TUNING.md",
          "docs/PRETRAINED_MODELS.md",
          "docs/ZERO_SHOT.md",
          "docs/QUANTIZATION.md"
        ],
        "Performance and Best Practices": [
          "docs/PERFORMANCE.md",
          "docs/REFACTORING.md"
        ]
      ],
      groups_for_modules: [
        "Core API": [
          Nasty,
          Nasty.Language.Behaviour,
          Nasty.Language.Registry
        ],
        Languages: [
          Nasty.Language.English,
          Nasty.Language.Spanish,
          Nasty.Language.Catalan
        ],
        Data: [
          Nasty.Data.CoNLLU,
          Nasty.Data.Corpus,
          Nasty.Data.OntoNotes
        ],
        "AST Nodes": [
          Nasty.AST.Node,
          Nasty.AST.Document,
          Nasty.AST.Paragraph,
          Nasty.AST.Sentence,
          Nasty.AST.Clause,
          Nasty.AST.Token,
          Nasty.AST.NounPhrase,
          Nasty.AST.VerbPhrase,
          Nasty.AST.PrepositionalPhrase,
          Nasty.AST.AdjectivalPhrase,
          Nasty.AST.AdverbialPhrase,
          Nasty.AST.Answer,
          Nasty.AST.Classification,
          Nasty.AST.ClassificationModel,
          Nasty.AST.Dependency,
          Nasty.AST.Event,
          Nasty.AST.Phrase,
          Nasty.AST.Phrase.Phrase,
          Nasty.AST.Relation,
          Nasty.AST.RelativeClause,
          Nasty.AST.Renderer
        ],
        "Semantic Structures": [
          Nasty.AST.Semantic.Entity,
          Nasty.AST.Semantic.Frame,
          Nasty.AST.Semantic.Role,
          Nasty.AST.Semantic.CorefChain,
          Nasty.AST.Semantic.Event,
          Nasty.AST.Semantic.Mention,
          Nasty.AST.Semantic.Modality,
          Nasty.AST.Semantic.Reference,
          Nasty.AST.Semantic.Relation,
          Nasty.AST.Intent
        ],
        "Language Components": [
          Nasty.Language.English.Tokenizer,
          Nasty.Language.English.POSTagger,
          Nasty.Language.English.Morphology,
          Nasty.Language.English.PhraseParser,
          Nasty.Language.English.SentenceParser,
          Nasty.Language.English.DependencyExtractor,
          Nasty.Language.English.EntityRecognizer,
          Nasty.Language.English.SemanticRoleLabeler,
          Nasty.Language.English.CoreferenceResolver,
          Nasty.Language.English.Summarizer,
          Nasty.Language.Catalan.DependencyExtractor,
          Nasty.Language.Catalan.EntityRecognizer,
          Nasty.Language.Catalan.Morphology,
          Nasty.Language.Catalan.POSTagger,
          Nasty.Language.Catalan.Parser,
          Nasty.Language.Catalan.PhraseParser,
          Nasty.Language.Catalan.Renderer,
          Nasty.Language.Catalan.SentenceParser,
          Nasty.Language.Catalan.Summarizer,
          Nasty.Language.Catalan.Tokenizer,
          Nasty.Language.English.AbstractiveSummarizer,
          Nasty.Language.English.Adapters.CoreferenceResolverAdapter,
          Nasty.Language.English.Adapters.EntityRecognizerAdapter,
          Nasty.Language.English.Adapters.SummarizerAdapter,
          Nasty.Language.English.AnswerExtractor,
          Nasty.Language.English.ClassificationConfig,
          Nasty.Language.English.CoreferenceConfig,
          Nasty.Language.English.EventExtractor,
          Nasty.Language.English.FeatureExtractor,
          Nasty.Language.English.QAConfig,
          Nasty.Language.English.QuestionAnalyzer,
          Nasty.Language.English.RelationExtractor,
          Nasty.Language.English.SRLConfig,
          Nasty.Language.English.TemplateExtractor,
          Nasty.Language.English.TextClassifier,
          Nasty.Language.English.TransformerNER,
          Nasty.Language.English.TransformerPOSTagger,
          Nasty.Language.English.WordSenseDisambiguator,
          Nasty.Language.GrammarLoader,
          Nasty.Language.Resources.LexiconLoader,
          Nasty.Language.Spanish.Adapters.CoreferenceResolverAdapter,
          Nasty.Language.Spanish.Adapters.EntityRecognizerAdapter,
          Nasty.Language.Spanish.Adapters.SummarizerAdapter,
          Nasty.Language.Spanish.CoreferenceConfig,
          Nasty.Language.Spanish.CoreferenceResolver,
          Nasty.Language.Spanish.DependencyExtractor,
          Nasty.Language.Spanish.EntityRecognizer,
          Nasty.Language.Spanish.FeatureExtractor,
          Nasty.Language.Spanish.Morphology,
          Nasty.Language.Spanish.POSTagger,
          Nasty.Language.Spanish.PhraseParser,
          Nasty.Language.Spanish.QAConfig,
          Nasty.Language.Spanish.QuestionAnalyzer,
          Nasty.Language.Spanish.SRLConfig,
          Nasty.Language.Spanish.SemanticRoleLabeler,
          Nasty.Language.Spanish.SentenceParser,
          Nasty.Language.Spanish.Summarizer,
          Nasty.Language.Spanish.TextClassifier,
          Nasty.Language.Spanish.Tokenizer
        ],
        Lexical: [
          Nasty.Lexical.WordNet,
          Nasty.Lexical.WordNet.Lemma,
          Nasty.Lexical.WordNet.Loader,
          Nasty.Lexical.WordNet.Relation,
          Nasty.Lexical.WordNet.Similarity,
          Nasty.Lexical.WordNet.Storage,
          Nasty.Lexical.WordNet.Synset
        ],
        Translation: [
          Nasty.Translation.Translator,
          Nasty.Translation.ASTTransformer,
          Nasty.Translation.TokenTranslator,
          Nasty.Translation.Agreement,
          Nasty.Translation.LexiconLoader,
          Nasty.Translation.WordOrder
        ],
        Rendering: [
          Nasty.Rendering.Text,
          Nasty.Rendering.PrettyPrint,
          Nasty.Rendering.Visualization
        ],
        Operations: [
          Nasty.Operations.Classification,
          Nasty.Operations.Classification.NaiveBayes,
          Nasty.Operations.QA.AnswerSelector,
          Nasty.Operations.QA.CandidateScorer,
          Nasty.Operations.QA.QAEngine,
          Nasty.Operations.QA.QuestionClassifier,
          Nasty.Operations.Summarization,
          Nasty.Operations.Summarization.Abstractive,
          Nasty.Operations.Summarization.Extractive
        ],
        Semantics: [
          Nasty.Semantic.Coreference.Clusterer,
          Nasty.Semantic.Coreference.Evaluator,
          Nasty.Semantic.Coreference.MentionDetector,
          Nasty.Semantic.Coreference.Neural.E2EResolver,
          Nasty.Semantic.Coreference.Neural.E2ETrainer,
          Nasty.Semantic.Coreference.Neural.MentionEncoder,
          Nasty.Semantic.Coreference.Neural.PairScorer,
          Nasty.Semantic.Coreference.Neural.Resolver,
          Nasty.Semantic.Coreference.Neural.SpanEnumeration,
          Nasty.Semantic.Coreference.Neural.SpanModel,
          Nasty.Semantic.Coreference.Neural.Trainer,
          Nasty.Semantic.Coreference.Resolver,
          Nasty.Semantic.Coreference.Scorer,
          Nasty.Semantic.CoreferenceResolution,
          Nasty.Semantic.EntityRecognition,
          Nasty.Semantic.EntityRecognition.RuleBased,
          Nasty.Semantic.SRL.AdjunctClassifier,
          Nasty.Semantic.SRL.CoreArgumentMapper,
          Nasty.Semantic.SRL.Labeler,
          Nasty.Semantic.SRL.PredicateDetector,
          Nasty.Semantic.WordSenseDisambiguation
        ],
        Statistics: [
          Nasty.Statistics.Evaluator,
          Nasty.Statistics.FeatureExtractor,
          Nasty.Statistics.ModelDownloader,
          Nasty.Statistics.ModelLoader,
          Nasty.Statistics.ModelRegistry,
          Nasty.Statistics.Neural.DataLoader,
          Nasty.Statistics.Neural.Embeddings,
          Nasty.Statistics.Neural.Inference,
          Nasty.Statistics.Neural.Preprocessing,
          Nasty.Statistics.Neural.Pretrained,
          Nasty.Statistics.Neural.Quantization.INT8,
          Nasty.Statistics.Neural.Transformers.CacheManager,
          Nasty.Statistics.Neural.Transformers.Config,
          Nasty.Statistics.Neural.Transformers.DataPreprocessor,
          Nasty.Statistics.Neural.Transformers.FineTuner,
          Nasty.Statistics.Neural.Transformers.Inference,
          Nasty.Statistics.Neural.Transformers.Loader,
          Nasty.Statistics.Neural.Transformers.Multilingual,
          Nasty.Statistics.Neural.Transformers.TokenClassifier,
          Nasty.Statistics.Neural.Transformers.TokenizerAdapter,
          Nasty.Statistics.Neural.Transformers.ZeroShot,
          Nasty.Statistics.Parsing.CYKParser,
          Nasty.Statistics.Parsing.Grammar,
          Nasty.Statistics.Parsing.Grammar.Rule,
          Nasty.Statistics.Parsing.PCFG,
          Nasty.Statistics.SequenceLabeling.CRF,
          Nasty.Statistics.SequenceLabeling.Features,
          Nasty.Statistics.SequenceLabeling.Optimizer,
          Nasty.Statistics.SequenceLabeling.Viterbi
        ],
        "Statistical Models": [
          Nasty.Statistics.Model,
          Nasty.Statistics.POSTagging.HMMTagger,
          Nasty.Statistics.POSTagging.ViterbiDecoder,
          Nasty.Statistics.PCFG
        ],
        "Neural Models": [
          Nasty.Statistics.Neural.Model,
          Nasty.Statistics.POSTagging.NeuralTagger,
          Nasty.Statistics.Neural.Architectures.BiLSTMCRF,
          Nasty.Statistics.Neural.Trainer
        ],
        "Code Interoperability": [
          Nasty.Interop.IntentRecognizer,
          Nasty.Interop.CodeGen.Elixir,
          Nasty.Interop.RagexBridge,
          Nasty.Interop.CodeGen.Explain
        ],
        Utilities: [
          Nasty.Utils.Traversal,
          Nasty.Utils.Query,
          Nasty.Utils.Validator,
          Nasty.Utils.Transform
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Nasty.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      # Neural Network Libraries
      {:axon, "~> 0.7"},
      {:nx, "~> 0.9"},
      {:exla, "~> 0.9"},
      {:bumblebee, "~> 0.6"},
      {:tokenizers, "~> 0.5"},
      # Doc / Test / Benchmarking
      {:credo, "~> 1.5", only: :dev},
      # {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:benchee, "~> 1.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test]}
    ]
  end
end
