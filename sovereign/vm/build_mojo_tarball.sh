#!/usr/bin/env bash
# vm/build_mojo_tarball.sh — Stage 1 (mojo-builder): build the open-source
# Mojo 1.2.0 compiler from source INSIDE a disposable VirtualBox build
# snapshot, and package ONLY the standalone native SDK into a versioned
# tarball + SHA256SUMS for the clean runtime snapshot.
#
# Run this INSIDE the mojo-builder snapshot (Ubuntu/Debian), as a user
# with sudo. It never touches the host OS, and it never installs anything
# into the runtime snapshot. Bazel's LLVM/MLIR build cache, the C++
# toolchain, and any build-time scripting stay in this disposable VM and
# die with it. What leaves the VM is one tarball + one checksum file.
#
# Usage:
#   EXPORT_DIR=/path/to/host-share bash vm/build_mojo_tarball.sh
# EXPORT_DIR is required: the directory the tarball + .sha256 are copied
# to (the host share the runtime VM mounts read-only). The build VM needs
# write access to that directory.
#
# Inputs: git + network to github.com only. No package manager installs
# a Mojo distribution here; the compiler is built from the open-source
# tree (github.com/modular/modular, tag max/v26.7.0) with ./bazelw.
#
# Outputs (in $WORK, then copied to $EXPORT_DIR):
#   mojo-1.2.0-linux-x86_64.tar.zst
#   mojo-1.2.0-linux-x86_64.tar.zst.sha256
# The tarball holds mojo-1.2.0/{bin/mojo, bin/lld, lib/*.so, lib/mojo/**}
# — the native binary, the compiled standard library (.mojopkg) and the
# required native runtime libraries only. Zero .py files, zero linkage
# against the Python runtime (checked with ldd before export).
#
# Status: written, NOT yet executed. The first real run happens inside
# the build VM; its output (tarball path + sha256) is recorded there.
set -euo pipefail

MOJO_VERSION="1.2.0"
MODULAR_TAG="max/v26.7.0"
MODULAR_REPO="https://github.com/modular/modular.git"
JOBS="${JOBS:-2}"
WORK="${WORK:-${HOME}/mojo-source-build}"
EXPORT_DIR="${EXPORT_DIR:-}"
TARBALL="mojo-${MOJO_VERSION}-linux-x86_64.tar.zst"

log() { printf '[build-mojo] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

[ -n "${EXPORT_DIR}" ] || die "EXPORT_DIR is not set — set it to the host-share directory the tarball is exported to."
mkdir -p "${EXPORT_DIR}" "${WORK}"

# --- Build toolchain (this VM only; never the runtime snapshot) ---
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  build-essential git curl ca-certificates zstd

# --- Source (open-source compiler, pinned tag) ---
rm -rf "${WORK}/modular"
git clone --depth 1 --branch "${MODULAR_TAG}" "${MODULAR_REPO}" "${WORK}/modular"
cd "${WORK}/modular"
log "source: ${MODULAR_REPO} @ ${MODULAR_TAG} ($(git rev-parse --short HEAD))"

# --- Build (Bazel, per upstream: ./bazelw run --config=build-mojo) ---
printf 'fn main() { print("hello from the source-built mojo") }\n' > "${WORK}/hello.mojo"
./bazelw run --config=build-mojo --jobs="${JOBS}" KGEN:mojo -- run "${WORK}/hello.mojo"

# --- Locate the built SDK (layout discovered at build time; fail loudly) ---
MOJO_BIN="$(find "${WORK}/modular/bazel-out" -name 'mojo' -type f -executable -not -path '*runfiles*' | head -n 1)"
[ -n "${MOJO_BIN}" ] || die "built mojo binary not found under bazel-out"
log "built binary: ${MOJO_BIN}"

# --- Stage ONLY the standalone SDK (native binary + stdlib + runtime libs) ---
STAGE="${WORK}/stage"
rm -rf "${STAGE}"
mkdir -p "${STAGE}/mojo-${MOJO_VERSION}/bin" "${STAGE}/mojo-${MOJO_VERSION}/lib"
cp "${MOJO_BIN}" "${STAGE}/mojo-${MOJO_VERSION}/bin/mojo"
chmod 755 "${STAGE}/mojo-${MOJO_VERSION}/bin/mojo"
BIN_DIR="$(dirname "${MOJO_BIN}")"
# Runtime libraries sitting next to the binary (libKGENCompilerRTShared, LLVM libs).
find "${BIN_DIR}" -maxdepth 1 -name '*.so*' -type f -exec cp {} "${STAGE}/mojo-${MOJO_VERSION}/lib/" \;
# Linker used by `mojo build`, if the build produced one.
[ -f "${BIN_DIR}/lld" ] && cp "${BIN_DIR}/lld" "${STAGE}/mojo-${MOJO_VERSION}/bin/lld"
# Compiled standard library (.mojopkg) — wherever the build put it.
STDLIB="$(find "${WORK}/modular/bazel-out" -name '*.mojopkg' -print -quit)"
[ -n "${STDLIB}" ] || die "no .mojopkg standard library found under bazel-out"
STDLIB_DIR="$(dirname "${STDLIB}")"
mkdir -p "${STAGE}/mojo-${MOJO_VERSION}/lib/mojo"
cp "${STDLIB_DIR}"/*.mojopkg "${STAGE}/mojo-${MOJO_VERSION}/lib/mojo/"
log "staged: $(find "${STAGE}" -type f | wc -l) files"

# --- Prove it is standalone: zero .py files, zero Python runtime linkage ---
if find "${STAGE}" -name '*.py' | grep -q .; then
  die ".py files present in the staged SDK — refusing to export"
fi
if ldd "${STAGE}/mojo-${MOJO_VERSION}/bin/mojo" | grep -qi 'py''thon'; then
  die "built mojo links a Python runtime library — refusing to export"
fi
log "ldd: no Python runtime linkage"

# --- Package (tarball + checksum) ---
(cd "${STAGE}" && tar --zstd -cf "${WORK}/${TARBALL}" "mojo-${MOJO_VERSION}")
(cd "${WORK}" && sha256sum "${TARBALL}" > "${TARBALL}.sha256")

# --- Verify the packaged binary before export ---
TEST_ROOT="${WORK}/test-install"
rm -rf "${TEST_ROOT}"
mkdir -p "${TEST_ROOT}"
tar --zstd -xf "${WORK}/${TARBALL}" -C "${TEST_ROOT}"
PKG_BIN="${TEST_ROOT}/mojo-${MOJO_VERSION}/bin/mojo"
export MODULAR_MAX_PACKAGE_ROOT="${TEST_ROOT}/mojo-${MOJO_VERSION}"
export MODULAR_MOJO_MAX_PACKAGE_ROOT="${TEST_ROOT}/mojo-${MOJO_VERSION}"
export MODULAR_MOJO_MAX_DRIVER_PATH="${PKG_BIN}"
export MODULAR_MOJO_MAX_IMPORT_PATH="${TEST_ROOT}/mojo-${MOJO_VERSION}/lib/mojo"
"${PKG_BIN}" --version
"${PKG_BIN}" run "${WORK}/hello.mojo"
log "packaged binary verified: --version + hello.mojo"

# --- Export (tarball + checksum) to the host share ---
cp "${WORK}/${TARBALL}" "${WORK}/${TARBALL}.sha256" "${EXPORT_DIR}/"
log "exported: ${EXPORT_DIR}/${TARBALL}"
log "sha256: $(cut -d' ' -f1 "${WORK}/${TARBALL}.sha256")"
log "Stage 1 done. Next: Stage 2 in the clean runtime snapshot — sovereign/vm/bootstrap.sh"
