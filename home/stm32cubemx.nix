# STM32CubeMX — pin, clock and peripheral configuration for STM32 parts, and
# the code generator that turns it into a CMake project. Package only: its
# preferences and the MCU/firmware-package database live in ~/.stm32cubemx
# and ~/STM32Cube, both downloaded and rewritten by the app itself.
#
# The user half of features.embedded; the probe access is
# modules/hardware/debug-probes.nix. The cross-compiler, CMake and OpenOCD
# come from each project's own dev shell, not from here.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.embedded {
  home.packages = [ pkgs.stm32cubemx ];
}
