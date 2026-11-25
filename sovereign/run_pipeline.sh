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

# run_pipeline.sh — master entry point: build -> verify -> emit SHA256SUMS
# Run inside the VirtualBox guest. On a host without Elixir/Mojo it
# skips compilation, still checks every script, and still emits
# receipts for the source tree. It never fetches a repo or a package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
RECEIPTS_DIR="${ROOT}/receipts"
mkdir -p "$RECEIPTS_DIR"

log() { printf '[pipeline] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

log "root: $ROOT"

# 1. Script syntax check (always runs, everywhere)
for f in vm/bootstrap.sh kernels/build_kernels.sh run_pipeline.sh; do
  bash -n "$f" && log "bash -n OK: $f"
done

# 2. Mojo kernels -> control/priv/
if have mojo; then
  log "building Mojo kernels"
  bash kernels/build_kernels.sh
else
  log "SKIP mojo build: 'mojo' not on PATH (expected on host; required in guest)"
fi

# 3. BEAM tests (ExUnit, OTP stdlib only)
if have mix; then
  log "BEAM tests"
  (cd control && mix test)
else
  log "SKIP mix test: 'mix' not on PATH (expected on host; required in guest)"
fi

# 4. BEAM release
if have mix; then
  log "building BEAM release"
  if (cd control && mix deps.get --only prod 2>/dev/null || true; mix release --overwrite); then
    log "BEAM release OK"
  else
    log "in-project release failed (host overlayfs File.cp quirk); retrying under /tmp"
    REL_TMP="$(mktemp -d)"
    (cd control && MIX_ENV=prod mix release --overwrite --path "${REL_TMP}/sbm-rel")
    log "release built under ${REL_TMP}/sbm-rel"
  fi
else
  log "SKIP mix release: 'mix' not on PATH (expected on host; required in guest)"
fi

# 5. Verify: receipts for every source file, then self-check
log "emitting receipts"
find vm kernels control docs README.md run_pipeline.sh -type f \
  \( -name '*.sh' -o -name '*.mojo' -o -name '*.ex' -o -name '*.exs' -o -name '*.md' \) \
  -print0 | sort -z | xargs -0 sha256sum > "${RECEIPTS_DIR}/SHA256SUMS"
sha256sum -c "${RECEIPTS_DIR}/SHA256SUMS" >/dev/null && log "sha256sum -c OK"
log "receipts: ${RECEIPTS_DIR}/SHA256SUMS ($(wc -l < "${RECEIPTS_DIR}/SHA256SUMS") files)"
log "pipeline done"
