defmodule Nasty.Application do
  @moduledoc """
  OTP Application for Nasty.

  Starts the Language.Registry and other supervised processes.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the language registry
      Nasty.Language.Registry,
      # Start the model registry
      Nasty.Statistics.ModelRegistry
    ]

    opts = [strategy: :one_for_one, name: Nasty.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Register languages after registry starts
      Nasty.Language.Registry.register(Nasty.Language.English)
      Nasty.Language.Registry.register(Nasty.Language.Spanish)
      Nasty.Language.Registry.register(Nasty.Language.Catalan)
      {:ok, pid}
    end
  end
end
