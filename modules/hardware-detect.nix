# Tak_OS · hardware-detect.nix — Applies the output of scripts/detect-hardware.sh
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Reads hardware-detected.nix (generated, untracked). When a value in
# features.kernelParams or features.gpu is "auto", it is taken from the
# detection; any explicit value is kept as written. Without the generated
# file the detected values fall back to safe defaults, so the config still
# evaluates on a fresh checkout.
#
# Detected fields:
#   kernelParams   → gpu.kernelParams     (generic | nvidia | amd)
#   driver         → gpu.driver           (none | amd | intel | nvidia | nvidia-prime)
#   kernelModules  → boot.kernelModules   (CPU virtualisation, e.g. kvm-intel)
#   initrdModules  → boot.initrd.availableKernelModules (GPU KMS + VM guest drivers)
#   guest          → VM guest services    (none | qemu | virtualbox | vmware | hyperv)
{ lib, features, ... }:
let
  generated = ../hardware-detected.nix;

  detected =
    if builtins.pathExists generated
    then import generated
    else {
      kernelParams = "generic";
      driver = "none";
      kernelModules = [ ];
      initrdModules = [ ];
      guest = "none";
    };

  resolve = value: fallback: if value == "auto" then fallback else value;
in
{
  gpu.kernelParams = resolve features.kernelParams detected.kernelParams;
  gpu.driver       = resolve features.gpu detected.driver;

  boot.kernelModules                  = detected.kernelModules;
  boot.initrd.availableKernelModules  = detected.initrdModules;

  # Guest tooling only switches on when the matching hypervisor is detected.
  vm.guest-services.enable             = lib.mkDefault (detected.guest == "qemu");
  virtualisation.virtualbox.guest.enable = lib.mkDefault (detected.guest == "virtualbox");
  virtualisation.vmware.guest.enable   = lib.mkDefault (detected.guest == "vmware");
  virtualisation.hypervGuest.enable    = lib.mkDefault (detected.guest == "hyperv");
}
