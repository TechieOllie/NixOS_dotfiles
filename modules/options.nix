{ lib, ... }:
{
  options.features = lib.mkOption {
    type = lib.types.submodule {
      options = {
        snapshots = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable automatic btrfs snapshots (snapper) of / and /home.";
        };
        niri = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Niri Wayland compositor (system package + session entry only; user config lives in home/niri.nix).";
        };
        gaming = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the gaming stack: Steam (Millennium-patched) with proton-cachyos, Xbox controller drivers, and Heroic on the Home Manager side.";
        };
        docker = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Docker daemon and Compose, with the primary user in the docker group.";
        };
        tailscale = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Tailscale daemon and trust the tailscale0 interface in the firewall.";
        };
        printing = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable CUPS printing and Avahi-based network printer/scanner discovery.";
        };
        kdeconnect = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable KDE Connect phone integration: the daemon and its tray indicator, plus the 1714-1764 firewall range pairing needs.";
        };
        cad = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the CAD stack: FreeCAD, on the Home Manager side.";
        };
        development = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable developer tooling beyond the universal terminal stack: IntelliJ IDEA and the Claude Code CLI, both on the Home Manager side.";
        };
        moonshine = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Moonshine streaming server: a headless Moonlight-compatible host exposing a full niri desktop, Steam Big Picture and a remote poweroff.";
        };
        workstation = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the operator's personal terminal environment (Ghostty, Git, Lazygit, Neovim, Yazi) on the Home Manager side. Off for hosts where the operator only holds an admin account rather than actually working on the machine; Zsh and Starship are unconditional and stay either way.";
        };
        gnome = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the GNOME desktop (GDM + GNOME Shell), independent of features.niri. A separate desktop stack for hosts that aren't running Niri/Noctalia.";
        };
      };
    };
    default = { };
    description = "Feature flags controlling optional functionality. Every toggle a host or profile can set must be declared here.";
  };
}
