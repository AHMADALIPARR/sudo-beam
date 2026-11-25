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

defmodule Sudo.KeyManager do
  @moduledoc "Stub for `sudo-key-manager-*` (Key Manager SDK). Keys are never logged or returned in plaintext by a stub."
  alias Sudo.Common

  @spec create_key(map()) :: Common.result(map())
  def create_key(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_key)
  end

  @spec get_key(String.t()) :: Common.result(map())
  def get_key(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_key)
  end

  @spec delete_key(String.t()) :: Common.result(:ok)
  def delete_key(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:delete_key)
  end

  @spec rotate_key(String.t()) :: Common.result(map())
  def rotate_key(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:rotate_key)
  end
end
