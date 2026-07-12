# the-entertaining-nios-laptop

Not yet bootstrapped — this is the machine the dotfiles are currently being
developed on, still running CachyOS. `hardware-configuration.nix` has
already been generated from the real hardware (read-only, alongside the live
CachyOS install), but the actual install is deliberately on hold until the
dotfiles are fully functional, since it wipes the target disk.

Left to do before this host can be bootstrapped:

- [ ] Resolve the real disk device in `disko.nix` (currently the placeholder
      `/dev/CHANGEME` — check via `lsblk` from the installer).
- [ ] Generate this host's sops age key and add it as a recipient in
      `.sops.yaml`.
- [ ] Create `secrets/secrets.yaml` (add `secrets.nix` to wire it in).
- [ ] Add `nixosConfigurations.the-entertaining-nios-laptop` to `flake.nix`.
- [ ] Run `nixos-anywhere` against this machine — only once ready to replace
      CachyOS.

See `CLAUDE.md`'s "Current state" section for the authoritative, kept-current
status; this list is a convenience copy for whoever is working in this
directory.
