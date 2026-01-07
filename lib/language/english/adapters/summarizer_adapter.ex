defmodule Nasty.Language.English.Adapters.SummarizerAdapter do
  @moduledoc """
  Adapter that bridges the English.Summarizer implementation to the
  generic Operations.Summarization behaviour.

  This allows the English summarizer to be used through the generic
  operations interface while maintaining backward compatibility.
  """

  @behaviour Nasty.Operations.Summarization

  alias Nasty.AST.Document
  alias Nasty.Language.English.Summarizer

  @impl true
  def summarize(%Document{} = document, opts \\ []) do
    # Delegate to existing English implementation
    sentences = Summarizer.summarize(document, opts)
    {:ok, sentences}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @impl true
  def methods do
    [:extractive, :mmr]
  end
end
