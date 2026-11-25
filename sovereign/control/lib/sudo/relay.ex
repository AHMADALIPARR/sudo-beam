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

defmodule Sudo.Relay do
  @moduledoc """
  Stub for `sudo-di-relay-*` and `sudo-di-edge-agent-*`
  (Decentralized Identity Relay / Edge Agent): postboxes, relay
  messages, and connections. Docs: guides/decentralized-identity.md.
  """
  alias Sudo.Common

  @spec create_postbox(map()) :: Common.result(map())
  def create_postbox(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_postbox)
  end

  @spec list_postboxes(Common.list_input()) :: Common.result(Common.page())
  def list_postboxes(_input \\ %{}), do: Common.not_implemented(:list_postboxes)

  @spec send_message(map()) :: Common.result(map())
  def send_message(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:send_message)
  end

  @spec list_messages(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_messages(postbox_id, _input \\ %{}) do
    with :ok <- Common.validate_id(postbox_id), do: Common.not_implemented(:list_messages)
  end

  @spec create_connection(map()) :: Common.result(map())
  def create_connection(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_connection)
  end
end
