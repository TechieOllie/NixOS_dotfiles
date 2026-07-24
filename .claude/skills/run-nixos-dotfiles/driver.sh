#!/usr/bin/env bash
# Smoke-test driver for this NixOS flake repo. There is no in-container app
# to click here: this repo's "output" is whole-machine NixOS system closures
# (deployed to real/virtual hardware via nixos-anywhere, elsewhere) plus a
# bootstrap installer ISO. "Driving" it means: does it still evaluate, and
# does it still build a real closure. Run this from the repo root (the
# directory containing flake.nix), or pass --repo <path>.
#
# Usage:
#   driver.sh check                 # nix flake check (fast: evals both
#                                    # hosts + the ISO package, no full build)
#   driver.sh eval   [host]         # eval-only, just resolves .drvPath
#                                    # (fastest — a few seconds, catches
#                                    # option/type errors with no build)
#   driver.sh build  [host]         # full closure build for one host,
#                                    # symlinks result into ./result-<host>.
#                                    # Heavy (a full system closure) — not
#                                    # run by `all`; use it deliberately,
#                                    # not as a routine every-change check.
#   driver.sh iso                   # build the installer ISO, ./result-iso
#                                    # — the one thing this repo actually
#                                    # ships as a build artifact, so this
#                                    # is the routine "real build" target.
#   driver.sh all    [host]         # check + eval, in that order — the
#                                    # routine, cheap, eval-only path.
#                                    # Deliberately does NOT build either
#                                    # host's full closure, and does NOT
#                                    # build the ISO — both are `build`/
#                                    # `iso`, opt-in only.
#
# host defaults to $DEFAULT_HOST below. Valid hosts (see flake.nix):
#   the-entertaining-nios-vm        # bootstrapped, the dev/verification host
#   the-entertaining-nios-laptop    # wired + eval-clean, not yet installed
#
# Exit code is 0 iff every step run actually succeeded — check this, don't
# just eyeball the output.

set -euo pipefail

DEFAULT_HOST="the-entertaining-nios-vm"
REPO="$(pwd)"

# Optional --repo <path> as the first argument.
if [ "${1:-}" = "--repo" ]; then
  REPO="$2"
  shift 2
fi
cd "$REPO"

if [ ! -f flake.nix ]; then
  echo "error: $REPO does not look like the repo root (no flake.nix here)" >&2
  exit 1
fi

cmd="${1:-check}"
host="${2:-$DEFAULT_HOST}"

# Noctalia Shell is fetched from its own Cachix cache (see
# modules/desktop/noctalia.nix) rather than nixpkgs — that substituter is
# only actually *trusted* once a host running this flake has been switched
# to at least once (chicken-and-egg: the trust comes from the config you're
# trying to build). On a machine that has never built/switched this flake
# before, pass these explicitly or `nix build` may build Noctalia from
# source instead of substituting it (~20 minutes, per flake.nix's own
# comment on the noctalia input) rather than failing outright.
NOCTALIA_SUBSTITUTER_ARGS=(
  --extra-substituters "https://noctalia.cachix.org"
  --extra-trusted-public-keys "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
)

do_check() {
  echo "== nix flake check (evals nixosConfigurations.* + packages.*, no build) =="
  nix flake check --no-build "${NOCTALIA_SUBSTITUTER_ARGS[@]}"
}

do_eval() {
  local h="$1"
  echo "== nix eval .#nixosConfigurations.$h.config.system.build.toplevel.drvPath =="
  nix eval --raw ".#nixosConfigurations.${h}.config.system.build.toplevel.drvPath"
  echo
}

do_build() {
  local h="$1"
  echo "== nix build .#nixosConfigurations.$h.config.system.build.toplevel =="
  nix build ".#nixosConfigurations.${h}.config.system.build.toplevel" \
    -o "result-${h}" -L "${NOCTALIA_SUBSTITUTER_ARGS[@]}"
  echo "-> $(readlink -f "result-${h}")"
}

do_iso() {
  echo "== nix build .#installer-iso =="
  nix build .#installer-iso -o result-iso -L "${NOCTALIA_SUBSTITUTER_ARGS[@]}"
  echo "-> $(readlink -f result-iso)/iso/"
  ls -la "$(readlink -f result-iso)/iso/"
}

case "$cmd" in
  check) do_check ;;
  eval)  do_eval "$host" ;;
  build) do_build "$host" ;;
  iso)   do_iso ;;
  all)
    do_check
    do_eval "$host"
    ;;
  *)
    echo "unknown command: $cmd (expected: check | eval | build | iso | all)" >&2
    exit 1
    ;;
esac
