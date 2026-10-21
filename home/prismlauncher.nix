# Prism Launcher — Minecraft instance manager (the maintained MultiMC
# fork). Rides features.gaming alongside home/heroic.nix rather than taking
# a flag of its own: same capability (this machine plays games), same purely
# user-level shape — no service, no system integration.
#
# Package only. Accounts, instances and per-instance mod sets live under
# ~/.local/share/PrismLauncher, written by the launcher itself and including
# a Microsoft account token; none of it is a declarative preference, and the
# token is exactly the kind of credential this repo keeps out of the store
# (same reasoning as home/feishin.nix's server config).
#
# No host-level Java: nixpkgs' wrapper already puts the JDKs the launcher
# needs on its own path, including a legacy one for old Minecraft versions.
#
# SDL_VIDEO_FORCE_EGL=1, because Minecraft 26.3+ can't get OpenGL under
# Umbriel otherwise. Its SDL3 window moves itself to Xwayland on any
# compositor without fifo-v1, but LWJGL still sees a Wayland session and
# picks libEGL.so.1, which the game then hands to SDL's X11 loader — GLX by
# default, which finds no glX* symbols in it:
# `OpenGL is not supported: Could not retrieve OpenGL functions`. Vanilla
# survives on its Vulkan fallback; an OpenGL-only mod (Sodium, Iris) aborts
# the JVM. Forcing EGL on X11 makes SDL agree with LWJGL and leaves the
# window on Xwayland, where SDL wants it for frame pacing;
# SDL_VIDEO_DRIVER=wayland also works but overrides that choice. The hint
# is SDL3's name — SDL2's SDL_VIDEO_X11_FORCE_EGL is ignored. Prism's
# environment reaches the game, so wrapping the launcher covers every
# instance. Scoped here rather than in a session variable because Steam and
# Proton games use SDL too. Older versions (GLFW, not SDL) never read it.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  prismlauncher = pkgs.symlinkJoin {
    name = "prismlauncher-sdl-egl";
    paths = [ pkgs.prismlauncher ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/prismlauncher --set SDL_VIDEO_FORCE_EGL 1
    '';
  };
in
lib.mkIf osConfig.features.gaming {
  home.packages = [ prismlauncher ];
}
