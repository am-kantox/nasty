defmodule Nasty.AST.Node do
  @moduledoc """
  Base types and utilities for AST nodes.

  All AST nodes include position information for error reporting and
  editor integration.
  """

  @typedoc """
  Line and column position in source text (1-indexed).
  """
  @type position :: {line :: pos_integer(), column :: pos_integer()}

  @typedoc """
  Byte offset in source text (0-indexed).
  """
  @type byte_offset :: non_neg_integer()

  @typedoc """
  Span representing a range in source text.

  Includes both line/column positions (for editors) and byte offsets
  (for efficient slicing).
  """
  @type span :: %{
          start_pos: position(),
          end_pos: position(),
          start_offset: byte_offset(),
          end_offset: byte_offset()
        }

  @typedoc """
  Language identifier (ISO 639-1 codes).

  Examples: `:en` (English), `:es` (Spanish), `:ca` (Catalan)
  """
  @type language :: atom()

  @doc """
  Creates a span from NimbleParsec position tracking.

  NimbleParsec provides byte offsets and line/column tuples.

  ## Examples

      iex> Nasty.AST.Node.make_span({1, 0}, 0, {1, 5}, 5)
      %{
        start_pos: {1, 0},
        end_pos: {1, 5},
        start_offset: 0,
        end_offset: 5
      }
  """
  @spec make_span(position(), byte_offset(), position(), byte_offset()) :: span()
  def make_span(start_pos, start_offset, end_pos, end_offset) do
    %{
      start_pos: start_pos,
      end_pos: end_pos,
      start_offset: start_offset,
      end_offset: end_offset
    }
  end

  @doc """
  Extracts text slice from source using span byte offsets.

  ## Examples

      iex> span = Nasty.AST.Node.make_span({1, 0}, 0, {1, 5}, 5)
      iex> Nasty.AST.Node.extract_text("Hello world", span)
      "Hello"
  """
  @spec extract_text(String.t(), span()) :: String.t()
  def extract_text(source, %{start_offset: start_off, end_offset: end_off}) do
    String.slice(source, start_off, end_off - start_off)
  end

  @doc """
  Merges two spans into a single span covering both ranges.

  ## Examples

      iex> span1 = Nasty.AST.Node.make_span({1, 0}, 0, {1, 5}, 5)
      iex> span2 = Nasty.AST.Node.make_span({1, 6}, 6, {1, 11}, 11)
      iex> Nasty.AST.Node.merge_spans(span1, span2)
      %{
        start_pos: {1, 0},
        end_pos: {1, 11},
        start_offset: 0,
        end_offset: 11
      }
  """
  @spec merge_spans(span(), span()) :: span()
  def merge_spans(span1, span2) do
    %{
      start_pos: span1.start_pos,
      end_pos: span2.end_pos,
      start_offset: span1.start_offset,
      end_offset: span2.end_offset
    }
  end
end
