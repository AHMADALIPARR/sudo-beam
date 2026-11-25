# Port protocol — KernelPort (Elixir) <-> Mojo workers

## Wire format

Erlang Port option `{:packet, 4}` adds / strips the length, so
both sides see only the packet body. On the wire (stdin/stdout
of the Mojo binary, fd 0 / fd 1):

```
request  = u32_be length, u8 opcode, payload
response = u32_be length, u8 status, payload
status: 0 = ok, 1 = mismatch / error, 2 = worker error
```

Mojo reads/writes the length + body with libc `read(0)` /
`write(1)` via `external_call`, exact counts, looping to EOF.
Max packet 65536 bytes (Mojo side; Elixir has no explicit cap
beyond the Port).

One call per Port at a time. KernelPort enforces a 5s timeout,
closes and reopens the Port on timeout or exit, and replies
`{:error, :worker_timeout}` / `{:error, {:worker_exited, code}}`.

## Workers and opcodes

### field_ops — `control/priv/field_ops`, `--port`
Goldilocks Fp, p = 2^64 - 2^32 + 1. Canonical inputs only.

| Opcode | Name | Request payload | Response payload (status 0) |
|---|---|---|---|
| 0x01 | fp_add | 16 bytes: a u64 BE, b u64 BE | 8 bytes: result u64 BE |
| 0x02 | fp_mul | 16 bytes: a u64 BE, b u64 BE | 8 bytes: result u64 BE |
| 0x03 | fp_neg | 8 bytes: a u64 BE | 8 bytes: result u64 BE |

Status 1 payload is ASCII ("bad opcode or length").

CLI mode kept: `field_ops` with no args runs the 9-check
self-test and prints `field_ops self-test: PASS (9 checks)`.

### holo_verify — `control/priv/holo_verify`, `--port`
Pure-MoJo SHA-256 (no stdlib SHA-256 in Mojo 1.2 — see the
file header). Mirrored and verified in Python:
`kernels/tests/verify_sha256_and_framing.py` (5 vectors +
500 random inputs vs hashlib, PASS 2026-11-24).

| Opcode | Name | Request payload | Response payload |
|---|---|---|---|
| 0x10 | verify | u16_be path_len, path bytes, 64 bytes expected-hex ASCII | status 0/1: 32-byte digest. status 2: ASCII error |

- status 0: digest matches expected hex.
- status 1: mismatch — payload is the *actual* digest.
  KernelPort returns `{:error, {:checksum_mismatch, actual_hex}}`.
- status 2: worker error — payload is ASCII
  ("unknown opcode", "short packet", "bad path length",
  "cannot read file").

CLI mode kept: `holo_verify <path> <expected-hex64>` prints
`VERIFIED <hex> <path>` (exit 0), `MISMATCH ...` (exit 1),
or usage / read error (exit 2).

## Elixir API (SovereignBeamMojo.KernelPort)

- `fp_add/2`, `fp_mul/2`, `fp_neg/1` -> `{:ok, integer}`
- `field_ops_self_test/0` -> `{:ok, %{checks: 9}}`, runs the
  same 9 checks as the CLI, but through the Port.
- `verify_artifact(path, expected_hex)` ->
  `{:ok, %{sha256: hex, path: path}}`
- `call(worker, opcode, payload)` -> `{:ok, payload}` raw,
  for debugging / future opcodes.

Missing binary: `{:error, :worker_not_available}`.
Busy Port: `{:error, :worker_busy}`.

## Guest test (after vm/bootstrap.sh)

```bash
bash run_pipeline.sh
# Port self-test through the BEAM (in the guest, iex -S mix):
#   SovereignBeamMojo.KernelPort.field_ops_self_test()
#   # => {:ok, %{checks: 9}}
#   SovereignBeamMojo.KernelPort.verify_artifact("README.md", "<sha256 from receipts/SHA256SUMS>")
#   # => {:ok, %{sha256: "<same>", path: "README.md"}}
# CLI checks (no BEAM needed):
./control/priv/field_ops
./control/priv/holo_verify README.md <sha256>
```

## What is NOT verified here

The Mojo code has NOT been compiled on this host — no Mojo
toolchain here, by design. The Python mirror verifies the
SHA-256 algorithm and the framing encode/decode, not Mojo
syntax. First guest compile is the real check, especially:
libc `read`/`write` via `external_call`, `String` indexing /
`chr()`, and `FileHandle.read_bytes()`. If any of those APIs
differ in Mojo 1.2, fix that one call site in the guest and
re-run the tests above — the protocol and the Elixir side
do not change.
