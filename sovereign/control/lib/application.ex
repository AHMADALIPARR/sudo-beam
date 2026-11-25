defmodule SovereignBeamMojo.Application do
  @moduledoc """
  Root supervisor. Supervises, in order:
  1. `SovereignBeamMojo.ReceiptStore` — SHA-256 receipt tracker
  2. `SovereignBeamMojo.KernelPort` — Mojo worker Port owner
  3. `Sudo.*` stubs — stateless function modules, no processes;
     they are listed here only so a future GenServer-per-SDK can
     be added as a child without changing the tree shape.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SovereignBeamMojo.ReceiptStore,
      SovereignBeamMojo.KernelPort
    ]

    opts = [strategy: :one_for_one, name: SovereignBeamMojo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
