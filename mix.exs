defmodule Nasty.MixProject do
  use Mix.Project

  def project do
    [
      app: :nasty,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Nasty",
      source_url: "https://github.com/yourusername/nasty",
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
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/yourusername/nasty"}
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
      {:benchee, "~> 1.0", only: :dev}
    ]
  end
end
