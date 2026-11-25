#!/usr/bin/env bash
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
