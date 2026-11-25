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

# sovereign-beam-mojo — Sudo Platform stubs

Original stubs, not a mirror, fork, or copy of any Sudo Platform
repository. No repo was cloned. No SDK source was copied.

The public surface was mapped only from:
- the public org listing at https://github.com/sudoplatform
  (67 public repos at time of mapping, 2026-11-24 — names,
  languages, and one-line descriptions only), and
- the public docs index at https://docs.sudoplatform.com/llms.txt
  (guide titles / section names only).

Every function below is a stub: it declares the shape of the
public operation, validates its arguments locally, and returns
`{:error, :not_implemented}`. Nothing here calls a Sudo backend,
holds credentials, or performs a real crypto / network operation.
Implementing a stub means replacing that one return with a real
call through `Sudo.ApiClient` / `Sudo.KernelPort`, under the
supervision tree — never by pasting vendor code in.

## Stack — exactly as specified

| Layer | Runtime | Role |
|---|---|---|
| VM containment | VirtualBox, host-only / internal network, read-only shared artifact mount, snapshot disk | Hypervisor boundary; execution never touches the host |
| Control plane | Elixir 1.20 / Erlang/OTP 29 (BEAM) | Supervision trees, GenServers, job queues, crash isolation. No heavy buffers on the BEAM heap. |
| Compute | Mojo 1.2 | Goldilocks field ops, binary packing / verification, SHA-256 receipts at native speed. Called only via a Port / NIF boundary. |
| Glue | POSIX Bash, `set -euo pipefail` | VM bootstrap, `mojo build`, `mix release`, `sha256sum -c`. No orchestration framework. |

## Verified on this host — 2026-11-24 (real runs, not simulations)

- Mojo 1.2.0: both kernels compile and run. `field_ops` self-test
  PASS (9 checks); `holo_verify` CLI VERIFIED on empty, `abc`,
  README.md, and 1,000,000 x `a`; MISMATCH exits 1, missing
  file / bad usage exit 2. Port loops pass for both workers.
- Elixir 1.20.5 / OTP 29 (built from source): `mix compile`
  17 files, exit 0. KernelPort Port calls through `mix run`:
  self-test `{:ok, %{checks: 9}}`, fp_mul / fp_add / fp_neg
  correct, verify ok / mismatch / missing-file all correct.
- `mix release` assembles (prod, `include_erts: false` — the
  release runs where OTP is installed system-wide) and boots:
  `rpc` self-test and verify pass through the running release,
  workers served from the release's own priv dir.
- `run_pipeline.sh` exits 0, receipts for 30 files, `sha256sum -c` OK.
- Host quirk, not a code bug: on this host's overlayfs,
  Elixir's `File.cp` returns `:eperm`, so an in-project release
  fails here; the pipeline falls back to building the release
  under /tmp. The VirtualBox guest (ext4) does not hit this.

## Layout

```
sovereign-beam-mojo/
├── vm/bootstrap.sh            # VirtualBox guest provisioning (OTP 29, Elixir 1.20, Mojo 1.2)
├── run_pipeline.sh            # build -> verify -> emit SHA256SUMS
├── kernels/
│   ├── field_ops.mojo         # Goldilocks Fp arithmetic + --port worker (0x01-0x03)
│   ├── holo_verify.mojo       # pure-MoJo SHA-256 verifier + --port worker (0x10)
│   └── build_kernels.sh       # mojo build -> priv/
├── control/
│   ├── mix.exs                # zero-bloat OTP app, no web framework, no deps
│   ├── config/config.exs
│   ├── test/
│   │   └── sha256_and_framing_test.exs  # ExUnit: SHA-256 vectors + framing + fp edge
│   └── lib/
│       ├── application.ex     # root Supervisor
│       ├── kernel_port.ex     # GenServer: persistent framed Ports, 5s timeout, reopen
│       ├── receipt_store.ex   # content-addressed SHA-256 receipt tracker
│       └── sudo/              # <-- Sudo Platform stubs (one module per SDK family)
│           ├── common.ex      # shared types, errors, pagination
│           ├── user.ex        # registration / authentication
│           ├── profiles.ex    # Sudos (digital identities)
│           ├── entitlements.ex# redeem / retrieve, admin definitions/sets/sequences
│           ├── email.ex       # addresses, folders, send/receive, drafts, aliases
│           ├── telephony.ex   # phone numbers, SMS, subscriptions
│           ├── virtual_cards.ex
│           ├── notification.ex
│           ├── key_manager.ex
│           ├── config_manager.ex
│           ├── api_client.ex  # the single outbound boundary — also a stub
│           ├── secure_id_verification.ex
│           ├── relay.ex       # Decentralized Identity relay / edge agent
│           └── logging.ex
├── docs/SURFACE_MAP.md        # repo -> stub module mapping, with sources
├── docs/PORT_PROTOCOL.md      # KernelPort <-> Mojo wire format, opcodes, guest tests
├── docs/API_CLIENT_DECISION.md # pick mock | real | local_only before any network
└── receipts/                  # SHA256SUMS emitted by run_pipeline.sh
```

## How to use (inside the VirtualBox guest)

```bash
bash vm/bootstrap.sh        # once, in the guest
bash run_pipeline.sh        # build kernels, build release, verify, emit receipts
```

On this host (no Elixir / Mojo installed) the pipeline detects the
missing toolchains, skips the compile steps, and still verifies
every script with `bash -n` and emits receipts for the source tree.
That is intentional: the host is not the build machine.

## Stub contract

- All public functions are `@spec`'d, take plain maps / binaries /
  keyword lists, and return `{:ok, term} | {:error, term}`.
- A stub never returns fake success data. It returns
  `{:error, :not_implemented}` (or `{:error, {:not_implemented, fun}}`
  where the caller needs the name).
- `Sudo.ApiClient` is the only module allowed to talk to a network.
  Today it is also a stub, so no traffic can leak out by accident.
- Secrets, API keys, and `sudoplatformconfig.json` are never
  committed here. `vm/bootstrap.sh` creates the config path empty
  and `0600`; you fill it in the guest, by hand.
