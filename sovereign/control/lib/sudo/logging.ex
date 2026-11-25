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

defmodule Sudo.Logging do
  @moduledoc """
  Stub for `sudo-logging-*` (Logging SDK). Local-only: writes to
  Elixir Logger. No remote sink, no PII — callers must not pass
  secrets, tokens, or message bodies here.
  """
  require Logger

  @spec log(atom(), String.t()) :: :ok
  def log(level, message) when is_atom(level) and is_binary(message) do
    Logger.log(level, message)
    :ok
  end
end
