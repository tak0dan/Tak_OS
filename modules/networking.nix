# Tak_OS · networking.nix — NetworkManager, hostname, and WiFi
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, lib, ... }:

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
  networking.hostName = "Tak0_NixOS";
  networking.networkmanager.enable = true;

  # ===========================================================================
  # 📶 WIFI-EDU — WPA2-Enterprise (PEAP/MSCHAPv2) persistent connection
  # ===========================================================================
  # Credentials are stored in GNOME Keyring (libsecret) and retrieved at login
  # by a systemd user service — no plaintext secrets files needed.
  #
  # ┌─ SETUP (one-time) ───────────────────────────────────────────────────────┐
  # │  secret-tool store --label="WIFI-EDU username" service wifi-edu key username │
  # │  secret-tool store --label="WIFI-EDU password" service wifi-edu key password │
  # └──────────────────────────────────────────────────────────────────────────┘
  #
  # The service runs after graphical-session.target (keyring is unlocked).
  # Polkit allows declared NetworkManager users to manage NM connections without sudo.
  #

  security.polkit.extraConfig = lib.optionalString (networkManagerUsers != [ ]) ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.NetworkManager.network-control" &&
          (${polkitUserMatch})) {
        return polkit.Result.YES;
      }
    });
  '';

  systemd.user.services.wifi-edu-keyring = {
    description = "Configure WIFI-EDU NetworkManager connection from GNOME Keyring";
    wantedBy = [ "graphical-session.target" ];
    after    = [ "graphical-session.target" ];

    path = with pkgs; [ libsecret networkmanager ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        script = pkgs.writeShellScript "wifi-edu-keyring-setup" ''
          EDU_USER=$(secret-tool lookup service wifi-edu key username 2>/dev/null || true)
          EDU_PASS=$(secret-tool lookup service wifi-edu key password 2>/dev/null || true)

          if [ -z "$EDU_USER" ] || [ -z "$EDU_PASS" ]; then
            echo "[wifi-edu] Credentials not found in keyring — skipping."
            exit 0
          fi

          if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "WIFI-EDU"; then
            nmcli connection modify WIFI-EDU \
              802-1x.identity  "$EDU_USER" \
              802-1x.password  "$EDU_PASS"
          else
            nmcli connection add \
              type              wifi        \
              con-name          WIFI-EDU    \
              ssid              WIFI-EDU    \
              wifi-sec.key-mgmt wpa-eap     \
              802-1x.eap        peap        \
              802-1x.identity   "$EDU_USER" \
              802-1x.password   "$EDU_PASS" \
              802-1x.phase2-auth mschapv2   \
              autoconnect       yes
          fi

          echo "[wifi-edu] Connection configured from keyring."
        '';
      in "${script}";
    };
  };
}
