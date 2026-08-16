# Testing on the VM, non-interactively

`the-entertaining-nios-vm` is the only host this repo verifies changes on,
and it is set up so a whole verification cycle — boot, rebuild, launch an
app, inspect the result — runs over SSH from the development machine with
no keyboard at its console and no password prompt.

This is a property of that host alone. The three settings it rests on live
in `hosts/the-entertaining-nios-vm/default.nix`, not in any module or
profile, and the comment block there explains why each is acceptable only
because this VM is disposable, host-local and key-only. Do not copy them to
the laptop or desktop.

## The cycle

```bash
virsh -c qemu:///system start the-entertaining-nios-vm   # if shut off
virsh -c qemu:///system domifaddr the-entertaining-nios-vm   # find its IP
VM=192.168.122.57                                        # whatever it reported

ssh ol@$VM 'cd ~/.dotfiles && git pull --ff-only'        # the live-dotfiles clone
ssh ol@$VM 'sudo nixos-rebuild switch --flake ~/.dotfiles#the-entertaining-nios-vm'
```

The IP comes from libvirt's DHCP lease and is *not* stable across
recreations of the domain — read it rather than assuming the last one.

`nixos-rebuild` re-evaluates the flake from `~/.dotfiles` on the VM, so a
change must be **pushed and pulled** to be tested; the working tree on the
development machine is invisible to it. To skip the round trip while
iterating, build the closure on the development machine and copy it, or
`scp` individual live-dotfiles files (see `live-dotfiles.md`).

Building the closure before switching is worthwhile when the switch is
the part you want to be quick:

```bash
ssh ol@$VM 'nix build --no-link ~/.dotfiles#nixosConfigurations.the-entertaining-nios-vm.config.system.build.toplevel'
```

## Reaching the graphical session

The VM autologins into niri at boot (greetd `initial_session`), so a
session exists without anyone touching the console. But an ad-hoc SSH shell
is not part of it: `NIRI_SOCKET`, `WAYLAND_DISPLAY` and friends live in the
session's own systemd `--user` manager, so a GUI command run straight over
SSH fails or silently starts on no display.

The `in-session` wrapper imports those variables and then execs:

```bash
ssh ol@$VM in-session niri msg windows
ssh ol@$VM in-session niri msg action load-config-file
ssh ol@$VM 'in-session zen-beta &'      # launch a GUI app into the session
```

Anything that must appear on screen needs it. Anything that doesn't (a
`--version` check, reading a file, `systemctl status`) does not.

Because `initial_session` only applies to the first login after boot, the
Noctalia greeter is still what you get after logging out — so the greeter
itself remains testable, by logging out rather than by rebooting.

## What this does not cover

Autologin and passwordless sudo make the *mechanics* non-interactive; they
don't make the verification automatic. Screenshots, "does this look right",
and anything that depends on rendering still need eyes on the VM's display
(virt-manager). The standing rule that **eval passing is not verification**
is unchanged — this only removes the friction that made people skip the
live check, it does not replace it.
