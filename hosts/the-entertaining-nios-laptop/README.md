# the-entertaining-nios-laptop

Not yet installed — this is the machine the dotfiles are currently being
developed on, still running CachyOS. Fully wired on the Nix side though:
real `hardware-configuration.nix` (generated read-only alongside the live
CachyOS install), a dedicated sops age key registered in `.sops.yaml`, an
encrypted `secrets/secrets.yaml` + `secrets.nix`, and a `nixosConfigurations`
entry in `flake.nix`. `nix eval` on this host's `system.build.toplevel`
succeeds.

Left to do before this host can actually be installed:

- [ ] Resolve the real disk device in `disko.nix` (currently the placeholder
      `/dev/CHANGEME` — check via `lsblk` from the installer).
- [ ] Decide whether this host gets the desktop stack. It currently sets no
      `features.niri` and imports no `modules/desktop/*`, so installing it
      as-is yields a machine with no graphical session — deliberate so far,
      since the desktop stack is developed against the VM only.
- [ ] Run `nixos-anywhere` against this machine — only once ready to replace
      CachyOS, since that step wipes the target disk.

See `CLAUDE.md`'s "Hosts" section for the authoritative, kept-current status;
this list is a convenience copy for whoever is working in this directory.
