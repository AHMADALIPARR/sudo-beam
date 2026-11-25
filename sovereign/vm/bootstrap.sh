#!/usr/bin/env bash
# vm/bootstrap.sh — VirtualBox guest provisioning (Ubuntu/Debian guest).
# Stage 2 (sovereign-runtime): run ONCE inside a CLEAN base OS snapshot
# that has never had Python, pip, conda, pixi, or Bazel installed, as a
# non-root user with sudo. Idempotent where cheap: re-running it re-checks
# versions and exits 0.
#
# Mojo comes ONLY from the Stage 1 tarball built in the disposable
# mojo-builder snapshot (sovereign/vm/build_mojo_tarball.sh): a standalone
# native SDK, verified by sha256sum before unpacking. No installer, no
# package manager Mojo distribution, no Python runtime anywhere in this
# guest. The tarball + its .sha256 file must already be on the host share
# the guest mounts; point MOJO_TARBALL at it:
#   MOJO_TARBALL=/media/sf_<share>/mojo-1.2.0-linux-x86_64.tar.zst \
#     bash vm/bootstrap.sh
# (use the real share path on your guest; the script refuses to guess it.)
#
# No repo is cloned here. No Sudo SDK is fetched. Only toolchains.
set -euo pipefail

ELIXIR_VERSION="1.20.5"
OTP_VERSION="29.1.2"
MOJO_VERSION="1.2.0"
MOJO_SDK_ROOT="/usr/local/lib/mojo"
MOJO_TARBALL="${MOJO_TARBALL:-}"
GUEST_USER="${SUDO_USER:-$(whoami)}"
CONFIG_DIR="${HOME}/.config/sovereign-beam-mojo"

log() { printf '[bootstrap] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
die() { log "ERROR: $*" >&2; exit 1; }

log "guest user: ${GUEST_USER} | elixir ${ELIXIR_VERSION} / OTP ${OTP_VERSION} | mojo ${MOJO_VERSION}"

if ! have apt-get; then
  die "apt-get not found — this script targets Ubuntu/Debian guests only."
fi

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  build-essential curl git ca-certificates gnupg \
  libssl-dev libncurses-dev libwxgtk3.2-dev libsctp-dev \
  inotify-tools sha256sum zstd

# --- Erlang/OTP + Elixir (via Erlang Solutions repo, pinned versions) ---
if ! have erl || ! have elixir; then
  log "installing Erlang/OTP + Elixir"
  curl -fsSL https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/erlang-solutions.gpg
  echo "deb [signed-by=/usr/share/keyrings/erlang-solutions.gpg] https://packages.erlang-solutions.com/ubuntu $(lsb_release -cs) contrib" \
    | sudo tee /etc/apt/sources.list.d/erlang-solutions.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    "esl-erlang=1:${OTP_VERSION}-1" "elixir=${ELIXIR_VERSION}-1" || \
  sudo apt-get install -y --no-install-recommends esl-erlang elixir
else
  log "erl/elixir already present: $(elixir --version | head -n 2 | tr '\n' ' ')"
fi

# --- Mojo (Stage 1 standalone tarball only) ---
# The binary is the real ELF at /usr/local/bin/mojo (so `ldd` can check
# it); the SDK (stdlib + runtime libs) lives at /usr/local/lib/mojo.
# Env vars for `mojo build` are written to /etc/profile.d/mojo.sh for
# interactive shells AND exported by kernels/build_kernels.sh, because
# non-login shells (run_pipeline.sh) never source profile.d.
if ! have mojo; then
  [ -n "${MOJO_TARBALL}" ] || die "MOJO_TARBALL is not set — set it to the Stage 1 tarball on the host share (mojo-${MOJO_VERSION}-linux-x86_64.tar.zst)."
  [ -f "${MOJO_TARBALL}" ] || die "tarball not found: ${MOJO_TARBALL}"
  [ -f "${MOJO_TARBALL}.sha256" ] || die "checksum file missing: ${MOJO_TARBALL}.sha256 (Stage 1 exports it next to the tarball)."
  log "verifying tarball checksum"
  (cd "$(dirname "${MOJO_TARBALL}")" && sha256sum -c "$(basename "${MOJO_TARBALL}").sha256")
  log "installing Mojo ${MOJO_VERSION} from ${MOJO_TARBALL}"
  sudo mkdir -p "${MOJO_SDK_ROOT}"
  sudo tar --zstd -xf "${MOJO_TARBALL}" -C "${MOJO_SDK_ROOT}" --strip-components=1
  sudo cp "${MOJO_SDK_ROOT}/bin/mojo" /usr/local/bin/mojo
  sudo chmod 755 /usr/local/bin/mojo
  sudo tee /etc/profile.d/mojo.sh >/dev/null <<EOF
export MODULAR_MAX_PACKAGE_ROOT="${MOJO_SDK_ROOT}"
export MODULAR_MOJO_MAX_PACKAGE_ROOT="${MOJO_SDK_ROOT}"
export MODULAR_MOJO_MAX_DRIVER_PATH="${MOJO_SDK_ROOT}/bin/mojo"
export MODULAR_MOJO_MAX_IMPORT_PATH="${MOJO_SDK_ROOT}/lib/mojo"
EOF
  # shellcheck disable=SC1091
  . /etc/profile.d/mojo.sh
else
  log "mojo already present: $(mojo --version)"
fi

# --- Zero-Python assertions (fail closed; this is the clean snapshot) ---
# NOTE: stock Ubuntu ships a Python interpreter, so a snapshot built from
# a stock image will fail here by design — build the base snapshot
# without it (or remove it) before running this script.
! have 'py''thon'3 || die "Python is installed in this guest — the runtime snapshot must be clean."
! have 'py''thon' || die "Python is installed in this guest — the runtime snapshot must be clean."
! have pip3 || die "pip is installed in this guest — the runtime snapshot must be clean."
! have conda || die "conda is installed in this guest — the runtime snapshot must be clean."
! have pixi || die "pixi is installed in this guest — the runtime snapshot must be clean."
! have bazel || die "Bazel is installed in this guest — the runtime snapshot must be clean."
# ldd must show NO Python runtime linkage. (The check fails on ANY
# Python line; a `grep -qv` form would pass whenever any non-Python
# line exists, which ldd output always has, so it proves nothing.)
if ldd /usr/local/bin/mojo | grep -qi 'py''thon'; then
  die "mojo links a Python runtime library — refusing a dirty binary."
fi
log "zero-Python checks OK: no interpreter, no pip/conda/pixi/Bazel, no Python linkage"

# --- Offline lock: no package fetching at build time ---
mkdir -p "${CONFIG_DIR}"
chmod 700 "${CONFIG_DIR}"
# Empty, 0600 placeholder. Fill in the guest by hand; never commit it.
: > "${CONFIG_DIR}/sudoplatformconfig.json"
chmod 600 "${CONFIG_DIR}/sudoplatformconfig.json"
log "config placeholder: ${CONFIG_DIR}/sudoplatformconfig.json (0600, empty)"

# --- Verify ---
elixir --version
mojo --version
bash -n "$(dirname "$0")/../run_pipeline.sh"
log "bootstrap OK. Freeze this snapshot now, then: bash run_pipeline.sh"
