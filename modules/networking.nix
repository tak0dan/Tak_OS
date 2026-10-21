# Tak_OS · networking.nix — NetworkManager, hostname, and polkit for NM users
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, lib, ... }:

let
  networkManagerUsers = builtins.attrNames (lib.filterAttrs (_: user:
    (user.isNormalUser or false)
    && builtins.elem "networkmanager" (user.extraGroups or [ ])
  ) config.users.users);

  polkitUserMatch =
    lib.concatStringsSep " || "
      (map (user: ''subject.user == "${user}"'') networkManagerUsers);
in
{
  config = {
    networking.hostName = "Tak0Nix";
    networking.networkmanager.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;

    security.polkit.extraConfig = lib.optionalString (networkManagerUsers != [ ]) ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.NetworkManager.network-control" &&
            (${polkitUserMatch})) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
