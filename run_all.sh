#!/bin/bash
# run_all.sh — build and verify the whole layered tree:
#   sudo-beam base (Java virtual sudo + AWK policy + Erlang gateway)
#   + sovereign/ on top (Elixir 1.20/OTP 29 control plane, Mojo 1.2
#   kernels, Sudo Platform stubs, Sudo.BeamSession bridge).
# Exit 0 only if every runnable step passes. A step whose toolchain
# is missing is SKIPPED with a clear line, never faked as a pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '[run_all] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

export ELIXIR_ERL_OPTIONS="${ELIXIR_ERL_OPTIONS:-+fnu}"
export LANG="${LANG:-C.UTF-8}"

# 1. Java / AWK tests for the base (needs javac + java).
if have javac && have java; then
  log "make test (Java/AWK, base)"
  (cd "$ROOT" && make test)
else
  log "SKIP make test: javac/java not installed"
fi

# 2. Sovereign pipeline: Mojo kernels, mix compile, KernelPort
#    self-test, receipts over the sovereign tree.
if have mojo && have mix; then
  log "sovereign pipeline"
  (cd "$ROOT/sovereign" && bash run_pipeline.sh)
else
  log "SKIP sovereign pipeline: mojo/mix not installed"
fi

# 3. Live bridge: Elixir drives the Java worker through
#    Sudo.BeamSession, then the Mojo verifier receipts the
#    session transcript. Needs java + elixir.
if have java && have elixir; then
  log "live BeamSession round-trip + transcript receipt"
  (cd "$ROOT/sovereign/control" && mix run -e '
    cmds = ["whoami", "sudo id", "sudo -l", "mkdir work", "write work/report \"hello from the sovereign layer\"", "cat work/report"]
    results = Sudo.BeamSession.run_commands("operator", cmds)
    Enum.each(Enum.zip(cmds, results), fn {c, r} -> IO.inspect(r, label: c) end)
    unless Enum.all?(results, &match?({:ok, %{exit: 0}}, &1)), do: raise("BeamSession round-trip failed")
    guest = Sudo.BeamSession.run_commands("guest", ["sudo id"])
    IO.inspect(guest, label: "guest sudo id (must be denied)")
    unless match?([{:ok, %{exit: 1}}], guest), do: raise("guest was not denied")
    transcript = Enum.map_join(Enum.zip(cmds, results), "\n", fn {c, {:ok, r}} -> "$ " <> c <> "\n" <> r.stdout end)
    path = Path.expand("../receipts/beam_session_transcript.txt", File.cwd!())
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, transcript)
    digest = :crypto.hash(:sha256, transcript) |> Base.encode16(case: :lower)
    {:ok, verified} = SovereignBeamMojo.KernelPort.verify_artifact(path, digest)
    IO.inspect(verified, label: "transcript verified by holo_verify")
  ')
else
  log "SKIP live BeamSession round-trip: java/elixir not installed"
fi

# 4. Receipts over the whole combined tree (source files only).
log "receipts for the combined tree"
mkdir -p "$ROOT/receipts"
(cd "$ROOT" && find . \
  -path ./.git -prune -o \
  -path ./build -prune -o \
  -path ./sovereign/control/_build -prune -o \
  -path ./sovereign/control/priv -prune -o \
  -path ./sovereign/control/deps -prune -o \
  -path ./beam/_build -prune -o \
  -path ./.mojo_cache -prune -o \
  -path ./receipts -prune -o \
  -path ./sovereign/receipts -prune -o \
  -type f -print0 | sort -z | xargs -0 sha256sum > receipts/SHA256SUMS)
(cd "$ROOT" && sha256sum -c receipts/SHA256SUMS)
log "receipts: $ROOT/receipts/SHA256SUMS ($(wc -l < "$ROOT/receipts/SHA256SUMS" | tr -d ' ') files)"

log "run_all done"
