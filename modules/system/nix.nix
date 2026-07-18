{ vars, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Remote deploys (`nixos-rebuild switch --target-host <user>@<host>`)
    # push built store paths in over SSH as that user; an untrusted user
    # gets rejected with "lacks a signature by a trusted key" since the
    # daemon won't accept unsigned paths from anyone but root otherwise.
    # (NixOS's own default of ["root"] merges in alongside this, so root
    # doesn't need repeating here.)
    trusted-users = [ vars.user.name ];
  };
}
