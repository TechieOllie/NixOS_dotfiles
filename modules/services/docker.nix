# Docker Engine + Compose.
{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
lib.mkIf config.features.docker {
  virtualisation.docker = {
    enable = true;

    # Socket activation: the daemon starts on first use of /var/run/docker.sock
    # rather than at every boot, which on a laptop is the difference between
    # paying for Docker only when a container is actually run and paying for
    # it always.
    enableOnBoot = false;

    # Reclaims disk from stopped containers and dangling images; without
    # it, /var/lib/docker grows without bound on a machine that builds
    # images regularly.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Membership in this group is root-equivalent by design: anyone in it can
  # start a container that bind-mounts / and writes to it. Accepted here
  # because the only member is the machine's sole interactive operator, who
  # already has sudo — but it is the reason this is a feature flag rather
  # than something base.nix turns on everywhere.
  users.users.${vars.user.name}.extraGroups = [ "docker" ];

  # Compose as the CLI plugin (`docker compose`), not the end-of-life
  # standalone v1 `docker-compose` script. The NixOS docker module has no
  # option for this — the plugin is just a package that installs itself
  # into the CLI's plugin directory.
  environment.systemPackages = [ pkgs.docker-compose ];
}
