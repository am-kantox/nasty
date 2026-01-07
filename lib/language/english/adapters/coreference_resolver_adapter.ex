defmodule Nasty.Language.English.Adapters.CoreferenceResolverAdapter do
  @moduledoc """
  Adapter that bridges the English.CoreferenceResolver implementation to the
  generic Semantic.CoreferenceResolution behaviour.
  """

  @behaviour Nasty.Semantic.CoreferenceResolution

  alias Nasty.AST.Document
  alias Nasty.Language.English.CoreferenceResolver

  @impl true
  def resolve(%Document{} = document, opts \\ []) do
    # Delegate to existing English implementation which returns {:ok, chains}
    case CoreferenceResolver.resolve(document, opts) do
      {:ok, chains} -> {:ok, %{document | coref_chains: chains}}
      error -> error
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @impl true
  def algorithms do
    [:rule_based]
  end
end
