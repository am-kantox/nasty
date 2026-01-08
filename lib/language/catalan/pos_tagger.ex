defmodule Nasty.Language.Catalan.POSTagger do
  @moduledoc """
  Part-of-speech tagger for Catalan using Universal Dependencies tagset.

  Tags Catalan words with grammatical categories: NOUN, VERB, ADJ, etc.
  """

  alias Nasty.AST.Token

  @spec tag_pos([Token.t()], keyword()) :: {:ok, [Token.t()]} | {:error, term()}
  def tag_pos(_tokens, _opts \\ []) do
    # TODO: Implement in Phase 3
    {:error, :not_implemented}
  end
end
