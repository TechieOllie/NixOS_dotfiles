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

    # nix-direnv's own recommendation, and the half of its caching that it
    # cannot arrange by itself. It plants a GC root in a project's `.direnv/`
    # pointing at the dev shell, which protects that shell's *outputs* — but
    # not the derivations behind them, so a `nix-collect-garbage -d` reaps the
    # intermediate build inputs and the next `cd` re-evaluates and refetches
    # the whole toolchain. Keeping both makes the cached shell survive a GC.
    # Unconditional rather than tied to features.workstation: these are store
    # policy, they cost only disk, and gating store policy on whether a host
    # has direnv installed would be the wrong axis.
    keep-outputs = true;
    keep-derivations = true;
  };
}
