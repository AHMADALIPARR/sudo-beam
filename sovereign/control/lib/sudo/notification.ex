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

defmodule Sudo.Notification do
  @moduledoc "Stub for `sudo-notification-*` / `sudo-notification-web` (Notification SDK)."
  alias Sudo.Common

  @spec register_device(map()) :: Common.result(map())
  def register_device(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:register_device)
  end

  @spec unregister_device(String.t()) :: Common.result(:ok)
  def unregister_device(device_id) do
    with :ok <- Common.validate_id(device_id), do: Common.not_implemented(:unregister_device)
  end

  @spec list_notifications(Common.list_input()) :: Common.result(Common.page())
  def list_notifications(_input \\ %{}), do: Common.not_implemented(:list_notifications)
end
