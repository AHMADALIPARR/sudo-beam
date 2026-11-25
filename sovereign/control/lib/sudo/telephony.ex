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

defmodule Sudo.Telephony do
  @moduledoc """
  Stub for `sudo-telephony-*` (Telephony SDK): phone numbers,
  text messaging, and subscriptions. Docs: guides/telephony.md,
  phone-numbers.md, text-messaging.md, subscriptions.md.
  """

  alias Sudo.Common

  @spec create_phone_number(map()) :: Common.result(map())
  def create_phone_number(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:create_phone_number)
  end

  @spec list_phone_numbers(Common.list_input()) :: Common.result(Common.page())
  def list_phone_numbers(_input \\ %{}), do: Common.not_implemented(:list_phone_numbers)

  @spec send_message(map()) :: Common.result(map())
  def send_message(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:send_message)
  end

  @spec list_messages(String.t(), Common.list_input()) :: Common.result(Common.page())
  def list_messages(number_id, _input \\ %{}) do
    with :ok <- Common.validate_id(number_id), do: Common.not_implemented(:list_messages)
  end

  @spec subscribe(map()) :: Common.result(map())
  def subscribe(attrs) do
    with :ok <- Common.validate_map(attrs), do: Common.not_implemented(:subscribe)
  end
end
