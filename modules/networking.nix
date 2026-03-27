{ config, pkgs, lib, ... }:

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
  # Polkit allows tak_1 to manage NetworkManager connections without sudo.
  #

  # Allow tak_1 to manage NM connections from user context
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.NetworkManager.network-control" &&
          subject.user == "tak_1") {
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
