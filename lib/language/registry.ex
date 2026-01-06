defmodule Nasty.Language.Registry do
  @moduledoc """
  Registry for managing natural language implementations.

  The registry maps language codes to their implementation modules
  and provides language detection and validation utilities.
  """

  use Agent

  alias Nasty.Language.Behaviour

  @typedoc """
  Language code (ISO 639-1).
  """
  @type language_code :: atom()

  @typedoc """
  Module implementing Nasty.Language.Behaviour.
  """
  @type language_module :: module()

  ## Client API

  @doc """
  Starts the language registry.

  Automatically called when the application starts.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Registers a language implementation module.

  Validates that the module implements the Language.Behaviour correctly
  before registration.

  ## Examples

      iex> Nasty.Language.Registry.register(Nasty.Language.English)
      :ok
      
      iex> Nasty.Language.Registry.register(InvalidModule)
      {:error, "Module does not implement Nasty.Language.Behaviour"}
  """
  @spec register(language_module()) :: :ok | {:error, String.t()}
  def register(module) do
    Behaviour.validate_implementation!(module)
    language_code = module.language_code()

    Agent.update(__MODULE__, fn registry ->
      Map.put(registry, language_code, module)
    end)

    :ok
  rescue
    e in ArgumentError ->
      {:error, Exception.message(e)}
  end

  @doc """
  Gets the implementation module for a language code.

  ## Examples

      iex> Nasty.Language.Registry.get(:en)
      {:ok, Nasty.Language.English}
      
      iex> Nasty.Language.Registry.get(:fr)
      {:error, :language_not_found}
  """
  @spec get(language_code()) :: {:ok, language_module()} | {:error, :language_not_found}
  def get(language_code) do
    case Agent.get(__MODULE__, fn registry -> Map.get(registry, language_code) end) do
      nil -> {:error, :language_not_found}
      module -> {:ok, module}
    end
  end

  @doc """
  Gets the implementation module for a language code, raising on error.

  ## Examples

      iex> Nasty.Language.Registry.get!(:en)
      Nasty.Language.English
      
      iex> Nasty.Language.Registry.get!(:fr)
      ** (RuntimeError) Language not found: :fr
  """
  @spec get!(language_code()) :: language_module() | no_return()
  def get!(language_code) do
    case get(language_code) do
      {:ok, module} -> module
      {:error, :language_not_found} -> raise "Language not found: #{inspect(language_code)}"
    end
  end

  @doc """
  Returns all registered language codes.

  ## Examples

      iex> Nasty.Language.Registry.registered_languages()
      [:en, :es, :ca]
  """
  @spec registered_languages() :: [language_code()]
  def registered_languages do
    Agent.get(__MODULE__, fn registry -> Map.keys(registry) end)
  end

  @doc """
  Checks if a language is registered.

  ## Examples

      iex> Nasty.Language.Registry.registered?(:en)
      true
      
      iex> Nasty.Language.Registry.registered?(:fr)
      false
  """
  @spec registered?(language_code()) :: boolean()
  def registered?(language_code) do
    Agent.get(__MODULE__, fn registry -> Map.has_key?(registry, language_code) end)
  end

  @doc """
  Unregisters a language implementation.

  ## Examples

      iex> Nasty.Language.Registry.unregister(:en)
      :ok
  """
  @spec unregister(language_code()) :: :ok
  def unregister(language_code) do
    Agent.update(__MODULE__, fn registry ->
      Map.delete(registry, language_code)
    end)

    :ok
  end

  @doc """
  Clears all registered languages.

  Primarily for testing purposes.

  ## Examples

      iex> Nasty.Language.Registry.clear()
      :ok
  """
  @spec clear() :: :ok
  def clear do
    Agent.update(__MODULE__, fn _registry -> %{} end)
    :ok
  end

  @doc """
  Detects the language of the given text.

  **Currently a stub** - returns {:error, :not_implemented}.

  Future implementation will use heuristics:
  - Character set analysis (Latin, Cyrillic, Arabic, etc.)
  - Common word frequency analysis
  - Statistical language models

  For now, language must be explicitly specified via the `:language` option.

  ## Examples

      iex> Nasty.Language.Registry.detect_language("Hello world")
      {:error, :not_implemented}
  """
  @spec detect_language(String.t()) :: {:ok, language_code()} | {:error, term()}
  def detect_language(_text) do
    {:error, :not_implemented}
  end

  @doc """
  Returns metadata for all registered languages.

  ## Examples

      iex> Nasty.Language.Registry.all_metadata()
      %{
        en: %{version: "1.0.0", features: [...]},
        es: %{version: "1.0.0", features: [...]}
      }
  """
  @spec all_metadata() :: %{language_code() => map()}
  def all_metadata do
    Agent.get(__MODULE__, fn registry ->
      Map.new(registry, fn {code, module} ->
        metadata =
          if function_exported?(module, :metadata, 0) do
            module.metadata()
          else
            %{}
          end

        {code, metadata}
      end)
    end)
  end
end
