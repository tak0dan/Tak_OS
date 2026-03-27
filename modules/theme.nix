# ==================================================
#  Tak_OS (2026)
#  Project URL: https://github.com/tak0dan/Tak_OS
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{
  pkgs,
  lib,
  config,
  ...
}: {
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    papirus-icon-theme
    bibata-cursors
    adwaita-qt
  ];

  environment.variables = {
    GTK2_RC_FILES = "${pkgs.gnome-themes-extra}/share/themes/Adwaita-dark/gtk-2.0/gtkrc";
    QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
  };

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  environment.etc = {
    "dconf/profile/user".text = ''
      user-db:user
      system-db:local
    '';
    "dconf/db/local.d/00_theme".text = ''
      [org/gnome/desktop/interface]
      color-scheme='prefer-dark'
      gtk-theme='Adwaita-dark'
      icon-theme='Papirus-Dark'
      cursor-theme='Bibata-Modern-Classic'
    '';
  };

  system.activationScripts.dconfUpdate = {
    deps = ["etc"];
    text = ''
      if [ -x ${pkgs.dconf}/bin/dconf ]; then
        if [ -d /etc/dconf/db ]; then
          ${pkgs.dconf}/bin/dconf update || true
        fi
      fi
    '';
  };
}
