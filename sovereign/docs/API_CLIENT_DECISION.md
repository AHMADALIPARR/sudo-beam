<!--
Copyright (C) 2026 AHMADALIPARR

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

SPDX-License-Identifier: AGPL-3.0-only
-->

# ApiClient decision — pick a mode before any network is wired

`Sudo.ApiClient` is still gated. No network call exists in this
tree yet. Pick one mode; I will wire only that mode.

## The three modes

### A. Local mock (offline) — recommended for wiring
- `mode: "mock"`, `endpoint: "http://127.0.0.1:4001/graphql"`
- ApiClient talks to a small mock GraphQL server running inside
  the VirtualBox guest only (host-only network, no internet).
- No Sudo account, no registration key, no credentials at all.
- What I will build after you pick this: a mock server stub
  (Elixir, stdlib only), canned responses for `User.get_user`
  and `Entitlements.get_entitlements`, and an end-to-end test
  `ApiClient -> mock -> KernelPort.verify -> ReceiptStore`.
- Use it to prove the wiring, then switch modes later.

### B. Real Sudo Platform runtime
- `mode: "real"`, endpoint taken from *your*
  `sudoplatformconfig.json` — never hard-coded here, never
  committed, never sent in chat.
- Needs, in the guest only, at
  `~/.config/sovereign-beam-mojo/` (0600):
  - `sudoplatformconfig.json` — the runtime-instance config
    from the Sudo Admin Console / Getting Started guide
  - `register_key.id` and `register_key.private` — a TEST
    registration key, if you want User registration to work
- Sudo Platform services are GraphQL (AppSync-style) behind
  that config; auth is via the identity token, not a static
  API key in code. I will wire `:httpc` (stdlib, no deps),
  read the endpoint + auth fields from the config file at
  runtime, and return `{:error, :config_missing}` until the
  files exist.
- Do NOT paste the config, the key id, or the private key in
  chat. Put the files in the guest by hand.

### C. Local-only, no network
- `mode: "local_only"`
- ApiClient stays disabled (`{:error, :network_disabled}`).
  Only KernelPort + ReceiptStore + field_ops are wired.
- Pick this if you want the crypto / receipt path proven
  before any endpoint exists at all.

## What is already done (endpoint-independent)
- `KernelPort` is a real GenServer that runs a Mojo CLI
  binary as a one-shot Port, with a 5s timeout, exit-status
  handling, and output parsing. See `control/lib/kernel_port.ex`.
  `verify_artifact/2` (holo_verify) and `field_ops_self_test/0`
  are the two entry points.
- `Sudo.ApiClient.mode/0` and `config/0` read
  `sudoplatformconfig.json` (via `:json`, OTP stdlib) and
  report `:unconfigured` until a mode is set. `request/1`
  returns a structured config error per mode, never a fake
  success and never a network call in the wrong mode.
- The Mojo side of the persistent Port protocol (binary
  framing over stdin/stdout) is NOT built yet — the CLIs are
  argv-based, so KernelPort uses one-shot Ports for now.
  That is the next KernelPort step after the ApiClient mode
  is chosen, if you want it.

## Files
- Example (placeholders only, no real values):
  `control/config/sudoplatformconfig.example.json`
- Copy it in the guest to
  `~/.config/sovereign-beam-mojo/sudoplatformconfig.json`
  and edit the `mode` field. Do not copy it into this repo
  with real values.
