# Tak_OS · home/common.nix — Common Home Manager baseline
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Repo-managed Home Manager baseline shared by every declared user.
{ pkgs, ... }:
{
  home.packages = [ pkgs.git ];

  # Add shared per-user defaults here over time.
}
