# Thin wrapper over the nix/nixos-rebuild commands this repo actually uses.
# Every recipe calls the underlying command verbatim — there is deliberately
# no logic here, so there's nothing that can drift from what you'd type by
# hand. `nix develop` (or direnv) puts `just` on PATH.
#
# Introduced in Phase 8, once the command surface had genuinely grown past
# one host; see ARCHITECTURE.md, "Command Runner".

# List available recipes.
default:
    @just --list

# Build and switch to a host's configuration. Destructive — this is the one
# recipe that changes a running machine.
switch host=`hostname`:
    nixos-rebuild switch --flake .#{{ host }}

# Build a host's system closure without switching to it.
build host=`hostname`:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel

# Evaluate a host without building anything — seconds, and enough to catch
# option typos, missing imports and failed assertions.
eval host=`hostname`:
    nix eval --raw .#nixosConfigurations.{{ host }}.config.system.build.toplevel.drvPath

# Roll back to the previous generation (covers NixOS and Home Manager
# together, since Home Manager is inside the system closure).
rollback:
    nixos-rebuild switch --rollback

# Update every flake input.
update:
    nix flake update

# The full gate: formatting, statix, deadnix, per-host evaluation *and*
# per-host closure builds. The same command CI runs — see
# .github/workflows/check.yml.
check:
    nix flake check

# The fast subset of `check`: lints and evaluation only, no closure builds.
check-fast:
    nix flake check --no-build

# Format every .nix file in place.
fmt:
    nix fmt

# Build the installer ISO used to bootstrap a new host.
iso:
    nix build .#installer-iso

# Re-encrypt a host's secrets after adding a recipient to .sops.yaml.
secrets-rekey host=`hostname`:
    sops updatekeys hosts/{{ host }}/secrets/secrets.yaml

# Deploy to a brand-new machine booted off the installer ISO.
# `ip` is the address the installer reports on boot.
install host ip:
    nixos-anywhere --flake .#{{ host }} root@{{ ip }}
