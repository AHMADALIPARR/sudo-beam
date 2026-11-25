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

defmodule Sudo.ApiClient do
  @moduledoc """
  Stub for `sudo-api-client-*` (API Client SDK) — gated on config.

  This is the SINGLE outbound boundary for every other Sudo stub.
  It makes NO network call yet. `request/1` returns a structured
  error until a mode is chosen (see docs/API_CLIENT_DECISION.md)
  and that mode is wired:

  - `:unconfigured` — no `sudoplatformconfig.json`, or no `mode`
  - `:local_only` — `{:error, :network_disabled}`
  - `:mock` — `{:error, :mock_not_configured}` until the mock
    server is built (mode A)
  - `:real` — `{:error, :not_implemented}` until the GraphQL
    call is wired against the config endpoint (mode B)

  Config is read at call time from the path in
  `Application.get_env(:sovereign_beam_mojo, :sudo_config_path)`,
  parsed with `:json` (OTP stdlib, no deps). Secrets are never
  logged and never stored here — the config file lives in the
  guest at 0600.
  """

  alias Sudo.Common

  @type mode :: :unconfigured | :mock | :real | :local_only
  @type request :: %{method: atom(), path: String.t(), body: map() | nil}

  @spec mode() :: mode()
  def mode do
    case config() do
      {:ok, %{"mode" => "mock"}} -> :mock
      {:ok, %{"mode" => "real"}} -> :real
      {:ok, %{"mode" => "local_only"}} -> :local_only
      _ -> :unconfigured
    end
  end

  @spec config() :: {:ok, map()} | {:error, term()}
  def config do
    path = Application.get_env(:sovereign_beam_mojo, :sudo_config_path, "")

    with {:ok, raw} <- File.read(path),
         {:ok, decoded} <- decode_json(raw) do
      {:ok, decoded}
    end
  end

  @spec endpoint() :: {:ok, String.t()} | {:error, term()}
  def endpoint do
    case config() do
      {:ok, %{"endpoint" => endpoint}} when is_binary(endpoint) -> {:ok, endpoint}
      {:ok, _} -> {:error, :endpoint_not_configured}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec request(request()) :: Common.result(map())
  def request(%{method: method, path: path} = _req)
      when is_atom(method) and is_binary(path) do
    case mode() do
      :unconfigured -> {:error, :config_missing}
      :local_only -> {:error, :network_disabled}
      :mock -> {:error, :mock_not_configured}
      :real -> Common.not_implemented(:request)
    end
  end

  def request(_), do: {:error, :invalid_input}

  defp decode_json(raw) do
    {:ok, :json.decode(raw)}
  rescue
    _ -> {:error, :invalid_config}
  catch
    _, _ -> {:error, :invalid_config}
  end
end
