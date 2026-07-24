# hosts/installer/

Not a real host — there's no `nixosConfigurations.installer` entry, and this
directory holds only `variables.nix` (the operator identity used to build the
bootstrap ISO). See that file's own comment for why it's split out from every
real host's `variables.nix` instead of reusing one of them.

## What it's for

`flake.nix`'s `packages.${system}.installer-iso` output is a minimal NixOS
installer image with the operator's SSH public key (from `variables.nix`
here) pre-authorized for `root`. Booting a target machine from it gives
`nixos-anywhere` something to SSH into immediately, with no manual console
step (setting a root password, enabling sshd, etc.) on the target at all.

It's a generic, host-independent image — the same ISO bootstraps any host in
this repo (VM, laptop, desktop, future hosts). It doesn't contain any
particular host's config; `nixos-anywhere --flake .#<name>` supplies that
separately once the target is booted from it.

## Build it

```bash
nix build .#installer-iso
```

The resulting image is a large (~1.4G) symlink at `./result/iso/*.iso`
(gitignored — never committed). Rebuild it any time the operator's SSH key in
`variables.nix` changes; otherwise the same image works for every host.

## Use it

Write the ISO to a USB drive and boot the target machine from it, then read
its IP (shown on the installer's own console/motd) and continue with
`nixos-anywhere` as described in
[`docs/bootstrapping-a-host.md`](../../docs/bootstrapping-a-host.md).

If the USB drive already has [Ventoy](https://www.ventoy.net/) installed on
it, no `dd`/imaging step is needed — just copy the `.iso` file onto the
drive's `Ventoy`-labeled partition (plain file copy, e.g. drag-and-drop or
`cp`), and Ventoy will offer it as a boot option automatically:

```bash
cp ./result/iso/*.iso /run/media/$USER/Ventoy/
```

If the drive doesn't have Ventoy on it yet, installing Ventoy itself
(`ventoy -i /dev/sdX`) wipes the entire drive first — double-check the device
path (`lsblk`) before running that.
