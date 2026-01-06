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
      Nasty.Language.Registry
    ]

    opts = [strategy: :one_for_one, name: Nasty.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Register English language after registry starts
      Nasty.Language.Registry.register(Nasty.Language.English)
      {:ok, pid}
    end
  end
end
