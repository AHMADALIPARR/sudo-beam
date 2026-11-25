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

defmodule Sudo.VirtualCards do
  @moduledoc """
  Stub for `sudo-virtual-cards-*`, `sudo-virtual-cards-simulator-*`,
  and `sudo-virtual-cards-admin-*` (Virtual Cards SDK).
  """

  alias Sudo.Common

  @spec create_card(map()) :: Common.result(map())
  def create_card(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_card)
  end

  @spec list_cards(Common.list_input()) :: Common.result(Common.page())
  def list_cards(_input \\ %{}), do: Common.not_implemented(:list_cards)

  @spec get_card(String.t()) :: Common.result(map())
  def get_card(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_card)
  end

  @spec update_card(String.t(), map()) :: Common.result(map())
  def update_card(id, attrs) do
    with :ok <- Common.validate_id(id),
         :ok <- Common.validate_map(attrs),
         do: Common.not_implemented(:update_card)
  end

  @spec suspend_card(String.t()) :: Common.result(map())
  def suspend_card(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:suspend_card)
  end

  @spec list_transactions(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_transactions(card_id, _input \\ %{}) do
    with :ok <- Common.validate_id(card_id), do: Common.not_implemented(:list_transactions)
  end
end
