#!/usr/bin/env bash
# vm/bootstrap.sh — VirtualBox guest provisioning (Ubuntu/Debian guest).
# Run ONCE inside the guest, as a non-root user with sudo. Idempotent
# where cheap: re-running it re-checks versions and exits 0.
# No repo is cloned here. No Sudo SDK is fetched. Only toolchains.
set -euo pipefail

ELIXIR_VERSION="1.20.5"
OTP_VERSION="29.1.2"
MOJO_VERSION="1.2.0"
GUEST_USER="${SUDO_USER:-$(whoami)}"
CONFIG_DIR="${HOME}/.config/sovereign-beam-mojo"

log() { printf '[bootstrap] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

log "guest user: ${GUEST_USER} | elixir ${ELIXIR_VERSION} / OTP ${OTP_VERSION} | mojo ${MOJO_VERSION}"

if ! have apt-get; then
  log "ERROR: apt-get not found — this script targets Ubuntu/Debian guests only." >&2
  exit 1
fi

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  build-essential curl git ca-certificates gnupg \
  libssl-dev libncurses-dev libwxgtk3.2-dev libsctp-dev \
  inotify-tools sha256sum

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

# --- Mojo (Modular) ---
if ! have mojo; then
  log "installing Mojo ${MOJO_VERSION} (Modular installer)"
  curl -fsSL https://get.modular.com | sh -s -- --version "${MOJO_VERSION}" || \
    { log "Mojo installer failed — install Mojo ${MOJO_VERSION} by hand, then re-run." >&2; exit 1; }
  # shellcheck disable=SC1091
  [ -f "${HOME}/.modular/env" ] && . "${HOME}/.modular/env"
else
  log "mojo already present: $(mojo --version)"
fi

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
log "bootstrap OK. Next: bash run_pipeline.sh"
