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

defmodule Sudo.Profiles do
  @moduledoc """
  Stub for `sudo-profiles-*` (Profiles SDK): Sudos — the digital
  identity for the modern age. Docs: guides/sudos.md,
  guides/sudos/managing-sudos.md.
  """

  alias Sudo.Common

  @type sudo :: %{id: String.t(), label: String.t()}

  @spec create_sudo(map()) :: Common.result(sudo())
  def create_sudo(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_sudo)
  end

  @spec list_sudos(Common.list_input()) :: Common.result(Common.page())
  def list_sudos(_input \\ %{}), do: Common.not_implemented(:list_sudos)

  @spec get_sudo(String.t()) :: Common.result(sudo())
  def get_sudo(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_sudo)
  end

  @spec update_sudo(String.t(), map()) :: Common.result(sudo())
  def update_sudo(id, attrs) do
    with :ok <- Common.validate_id(id),
         :ok <- Common.validate_map(attrs),
         do: Common.not_implemented(:update_sudo)
  end

  @spec delete_sudo(String.t()) :: Common.result(:ok)
  def delete_sudo(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:delete_sudo)
  end
end
