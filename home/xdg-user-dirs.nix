# Found live while investigating why Nautilus wasn't showing distinct
# icons for Documents/Downloads/Pictures/etc.: nothing in this repo had
# ever configured XDG user directories at all — confirmed on the VM,
# `~/.config/user-dirs.dirs` didn't exist, and `xdg-user-dirs-update` (the
# tool that normally creates it) wasn't even installed. Without it, GLib/
# Nautilus has no way to recognize those folders as special at all (this is
# unrelated to icon theming — it's what makes Nautilus request the
# "folder-download"/"folder-pictures"/etc. icon names in the first place
# instead of the generic "inode-directory" one every other folder gets).
# The directories already existed on disk (created ad hoc, not via this
# mechanism), which is why they showed up as plain folders rather than
# missing entirely.
#
# `projects` is home-manager's own non-standard addition (not a real
# freedesktop XDG user directory) — disabled since it wasn't asked for and
# isn't part of what Nautilus/GTK actually special-case.
#
# Self-gates on osConfig.features.niri, same convention as home/nautilus.nix
# — XDG user dirs only matter for GUI apps (file managers, browsers' save
# dialogs, ...), all niri-gated in this repo today.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.niri {
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    projects = null;
  };
}
