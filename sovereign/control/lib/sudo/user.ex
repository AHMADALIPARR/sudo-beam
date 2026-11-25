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

defmodule Sudo.User do
  @moduledoc """
  Stub for `sudo-user-*` (User SDK): the glue between a user and
  their Sudo identities — registration and authentication.
  Docs: guides/users.md, guides/users/registration.md,
  guides/users/authentication.md. No network call is made here.
  """

  alias Sudo.Common

  @type user :: %{id: String.t(), username: String.t()}

  @spec register(map()) :: Common.result(user())
  def register(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:register)
  end

  @spec sign_in(map()) :: Common.result(%{token: binary(), user: user()})
  def sign_in(creds) do
    with :ok <- Common.validate_map(creds), do: Common.not_implemented(:sign_in)
  end

  @spec sign_out() :: Common.result(:ok)
  def sign_out, do: Common.not_implemented(:sign_out)

  @spec get_user() :: Common.result(user())
  def get_user, do: Common.not_implemented(:get_user)

  @spec reset_password(map()) :: Common.result(:ok)
  def reset_password(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:reset_password)
  end

  @spec delete_user() :: Common.result(:ok)
  def delete_user, do: Common.not_implemented(:delete_user)
end
