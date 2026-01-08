defmodule Nasty.Language.Catalan.Parser do
  @moduledoc """
  Parser for Catalan sentences and phrases.
  """

  alias Nasty.AST.{Document, Token}

  @spec parse([Token.t()], keyword()) :: {:ok, Document.t()} | {:error, term()}
  def parse(_tokens, _opts \\ []) do
    # TODO: Implement in Phase 5
    {:error, :not_implemented}
  end
end
