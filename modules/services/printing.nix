# CUPS printing plus network printer discovery.
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
}
