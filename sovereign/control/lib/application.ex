# Copyright (C) 2026 AHMADALIPARR
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-only

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
