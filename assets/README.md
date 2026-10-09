# assets/

Static files the configuration copies into the Nix store and points system
state at — as opposed to `wallpapers/`, which is read live from each host's
own clone and never enters the store.

- `avatar.jpg` — the operator's account picture, declared on every host by
  `modules/system/users.nix` (AccountsService, so the greeter, GDM and
  Noctalia's own fallback all show it).

Anything here is public: this repo is, and so is every host's store.
