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

defmodule Sudo.ConfigManager do
  @moduledoc "Stub for `sudo-config-manager-*` (Config Manager SDK)."
  alias Sudo.Common

  @spec get_config() :: Common.result(map())
  def get_config, do: Common.not_implemented(:get_config)

  @spec refresh_config() :: Common.result(map())
  def refresh_config, do: Common.not_implemented(:refresh_config)
end
