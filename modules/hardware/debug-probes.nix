# Debug probes for microcontroller work: an ST-Link (or any other probe
# OpenOCD knows) usable without root, plus the probe's virtual serial port.
# System-level because both are udev/group questions a user-level package
# can't answer. The toolchain itself is deliberately *not* here: every
# project pins its own compiler and OpenOCD in its own flake dev shell
# (TechieOllie/project-templates, `stm32`), so an old project keeps
# building after a `nix flake update` of this repo. The user half — STM32CubeMX
# — is home/stm32cubemx.nix.
{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
lib.mkIf config.features.embedded {
  # OpenOCD's rules rather than stlink's own: they cover the ST-Link too,
  # but grant access through TAG+="uaccess" (the logged-in seat user) where
  # stlink's set MODE 0666 for everyone, and they also cover the other
  # probes OpenOCD can drive (CMSIS-DAP, J-Link, FTDI adapters).
  services.udev.packages = [ pkgs.openocd ];
  # The same rules also name GROUP="plugdev", which NixOS doesn't create;
  # udev would otherwise log an unknown-group error for every matching
  # device. Access still comes from uaccess, not from membership.
  users.groups.plugdev = { };

  # The ST-Link's virtual COM port (/dev/ttyACM*) is root:dialout 0660 and
  # uaccess doesn't reach tty devices, so UART output needs the group.
  users.users.${vars.user.name}.extraGroups = [ "dialout" ];
}
