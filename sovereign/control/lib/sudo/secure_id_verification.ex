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

defmodule Sudo.SecureIdVerification do
  @moduledoc "Stub for `sudo-secure-id-verification-*` (Secure ID Verification SDK)."
  alias Sudo.Common

  @spec start_verification(map()) :: Common.result(map())
  def start_verification(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:start_verification)
  end

  @spec get_verification(String.t()) :: Common.result(map())
  def get_verification(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:get_verification)
  end

  @spec cancel_verification(String.t()) :: Common.result(:ok)
  def cancel_verification(id) do
    with :ok <- Common.validate_id(id), do: Common.not_implemented(:cancel_verification)
  end
end
