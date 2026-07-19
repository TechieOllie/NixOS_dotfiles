# Lets dynamically-linked, non-Nix-packaged binaries run on NixOS by
# providing a stub dynamic linker + common libraries at the FHS-expected
# paths. Needed for anything installed by a tool other than Nix that
# ships prebuilt binaries -- confirmed live: Mason's `ruff` install (a
# manylinux Python wheel) failed with "Could not start dynamically
# linked executable" without this. Unconditional, no features.* flag —
# every real host that installs tooling outside Nix (Mason, npm global
# installs, etc.) needs this, so there's no per-host axis of variation
# for a flag to express.
{ ... }:
{
  programs.nix-ld.enable = true;
}
