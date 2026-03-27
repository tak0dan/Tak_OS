{ config, pkgs, lib, ... }:

{
  ############################
  # Virtualisation — Docker
  ############################
  # Enabled together with VirtualBox via features.virtualisation in configuration.nix.
  virtualisation.docker.enable = true;

  ############################
  # Virtualisation — VirtualBox Host
  ############################
  virtualisation.virtualbox.host = {
    enable = true;

    # Extension Pack adds USB 2/3, RDP, NVMe, disk encryption, etc.
    # Requires nixpkgs.config.allowUnfree = true in your configuration.nix.
    enableExtensionPack = true;

    # Kernel module hardening: set false only if you need raw-mode
    # (legacy 32-bit guests without HW-virt). Leave true for modern guests.
    enableHardening = true;

    # Build the vboxdrv kernel module via DKMS-style in-tree build.
    # Keep true unless you're on a custom kernel without module support.
    addNetworkInterface = true;   # adds vboxnet0 host-only adapter
  };

  ############################
  # Guest additions (if this machine ever runs *as* a VM guest too)
  # Uncomment only if needed — host and guest additions conflict.
  ############################
  # virtualisation.virtualbox.guest = {
  #   enable = true;
  #   draganddrop = true;
  # };

  ############################
  # User access
  ############################
  users.users.tak_1.extraGroups = [ "vboxusers" ];

  ############################
  # Allow the unfree Extension Pack licence
  ############################
  nixpkgs.config.allowUnfree = true;

  ############################
  # Optional: keep VirtualBox VMs on a dedicated path
  # (per-user override in ~/.config/VirtualBox/VirtualBox.xml is also fine)
  ############################
  # environment.variables.VBOX_USER_HOME = "/var/lib/virtualbox";

  ############################
  # Optional: expose the VBoxManage CLI to all users
  ############################
  environment.systemPackages = with pkgs; [
    virtualbox   # brings in VBoxManage, VBoxHeadless, etc.
  ];
}
