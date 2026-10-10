# fwupd: firmware updates from the LVFS for whatever on the machine
# supports them — commonly NVMe drives, sometimes peripherals and system
# firmware. Nothing is applied automatically: the daemon only answers when
# asked (`fwupdmgr refresh && fwupdmgr get-updates`, then `fwupdmgr
# update`), so it is safe to have everywhere, and a host with nothing on
# the LVFS (the VM) just reports no devices.
{ ... }:
{
  services.fwupd.enable = true;
}
