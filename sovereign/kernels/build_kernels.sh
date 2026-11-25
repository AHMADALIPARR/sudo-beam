#!/usr/bin/env bash
# kernels/build_kernels.sh — compile Mojo kernels to control/priv/
# Requires `mojo` on PATH (installed by vm/bootstrap.sh in the guest).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/control/priv"
mkdir -p "$OUT"

command -v mojo >/dev/null 2>&1 || { echo "mojo not found" >&2; exit 1; }

mojo build "${ROOT}/kernels/field_ops.mojo" -o "${OUT}/field_ops"
mojo build "${ROOT}/kernels/holo_verify.mojo" -o "${OUT}/holo_verify"
chmod 755 "${OUT}/field_ops" "${OUT}/holo_verify"
echo "kernels built: ${OUT}/field_ops ${OUT}/holo_verify"
