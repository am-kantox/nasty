defmodule Nasty.Language.English.ClassificationConfig do
  @moduledoc """
  English-specific configuration for text classification.

  Provides stop words for feature extraction.
  """

  # Stop words to exclude from BoW features
  @stop_words MapSet.new(~w(
    a an the this that these those
    is are was were be been being
    have has had having
    do does did doing done
    will would shall should may might can could must
    i me my mine you your yours he him his she her hers it its
    we us our ours they them their theirs
    in on at by for with from to of about
    and or but nor so yet
    as if because when where while
  ))

  @doc """
  Returns the set of stop words for English.
  """
  @spec stop_words() :: MapSet.t()
  def stop_words, do: @stop_words

  @doc """
  Returns the complete configuration map for classification.
  """
  @spec config() :: map()
  def config do
    %{
      stop_words: stop_words()
    }
  end
end
