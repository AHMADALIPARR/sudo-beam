#!/usr/bin/env bash
# kernels/build_kernels.sh — compile Mojo kernels to control/priv/
# Requires `mojo` on PATH (installed by vm/bootstrap.sh in the guest).
# The standalone Mojo binary needs its SDK env vars (there is no launcher
# that sets them); export them here when they are not already set, so
# `mojo build` works from non-login shells (run_pipeline.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/control/priv"
mkdir -p "$OUT"

command -v mojo >/dev/null 2>&1 || { echo "mojo not found" >&2; exit 1; }

if [ -z "${MODULAR_MOJO_MAX_IMPORT_PATH:-}" ] && [ -d /usr/local/lib/mojo/lib/mojo ]; then
  export MODULAR_MAX_PACKAGE_ROOT="/usr/local/lib/mojo"
  export MODULAR_MOJO_MAX_PACKAGE_ROOT="/usr/local/lib/mojo"
  export MODULAR_MOJO_MAX_DRIVER_PATH="/usr/local/lib/mojo/bin/mojo"
  export MODULAR_MOJO_MAX_IMPORT_PATH="/usr/local/lib/mojo/lib/mojo"
fi

mojo build "${ROOT}/kernels/field_ops.mojo" -o "${OUT}/field_ops"
mojo build "${ROOT}/kernels/holo_verify.mojo" -o "${OUT}/holo_verify"
chmod 755 "${OUT}/field_ops" "${OUT}/holo_verify"
echo "kernels built: ${OUT}/field_ops ${OUT}/holo_verify"
