# Tak_OS · nh.nix — nh — Nix helper CLI (nicer nixos-rebuild wrapper)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{pkgs, ...}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = false;
      extraArgs = "--keep-since 7d --keep 5";
    };
  };

  environment.systemPackages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
