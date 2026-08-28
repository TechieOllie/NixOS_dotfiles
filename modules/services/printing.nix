# CUPS printing plus network printer discovery, plus scanning (SANE).
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.printing {
  services.printing = {
    enable = true;

    # Driverless IPP Everywhere / AirPrint covers most printers made in the
    # last decade without a vendor driver; gutenprint is the fallback for
    # older hardware. Vendor-specific driver packages are deliberately not
    # listed — add one here only when a printer that's actually attached
    # needs it, rather than guessing at a set now.
    drivers = [ pkgs.gutenprint ];
  };

  # Discovery over mDNS. CUPS finds driverless printers through Avahi, so
  # without this a network printer has to be added by IP address by hand.
  # nssmdns4 puts .local names into normal name resolution too.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Scanning. Rides the same features.printing flag rather than a separate
  # one: every host that wants network printer discovery here also wants
  # network scanner discovery, and CUPS/Avahi's discovery story already
  # covers both — a features.scanning flag would just be a second way to
  # say "this host has peripherals," the same reasoning that dropped
  # features.bluetooth (see ARCHITECTURE.md's "Features" section).
  # hardware.sane.enable pulls in the SANE backends (genesys/airscan/etc. are
  # covered by the default backend set, so nothing further is named here
  # until a specific scanner needs it — same "add a driver only once real
  # hardware needs it" rule as the printer drivers above). It does NOT add
  # any user to the "scanner"/"lp" groups on its own (checked against this
  # pin's hardware/sane.nix) — a host that wants a given user to actually
  # be able to scan still needs users.users.<name>.extraGroups to include
  # them, same as any other udev-gated device class.
  hardware.sane.enable = true;
}
