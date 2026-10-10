# NTSync: Windows' synchronisation primitives (mutexes, semaphores, events)
# implemented in the kernel, so Wine/Proton no longer has to emulate them in
# userspace through wineserver. The gain is in CPU-bound and heavily
# threaded games — fewer stalls, better frame pacing.
#
# The module ships with any 6.14+ kernel, CachyOS's included, but nothing
# loads it on demand: without this line /dev/ntsync simply doesn't exist
# and Proton silently falls back to its older fsync path. No Proton-side
# switch is needed — current proton-cachyos and GE-Proton both use the
# device whenever it is present. The kernel creates it world-accessible,
# so no udev rule is needed either.
{ config, lib, ... }:
lib.mkIf config.features.gaming {
  boot.kernelModules = [ "ntsync" ];
}
