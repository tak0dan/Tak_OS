# Tak_OS · docker.nix — Docker engine with a rolling nixpkgs-major default
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Keep Docker declarative and override-friendly:
#   - features.virtualisation still owns whether Docker is enabled
#   - virtualisation.docker.package can still be set explicitly elsewhere
#   - when left unspecified, select the highest docker_<major> attr in nixpkgs
#
# This avoids pinning the system to an older default alias that may later become
# insecure while a newer docker_<major> is already available in the channel.
{ pkgs, lib, features, ... }:

let
  dockerMajor = name:
    let
      match = builtins.match "docker_([0-9]+)" name;
    in
    if match == null then null else lib.toInt (builtins.head match);

  dockerAttrNames =
    builtins.filter (name: dockerMajor name != null) (builtins.attrNames pkgs);

  latestDockerAttr =
    if dockerAttrNames == []
    then null
    else builtins.head (builtins.sort (a: b: dockerMajor a > dockerMajor b) dockerAttrNames);

  latestDockerPackage =
    if latestDockerAttr == null
    then pkgs.docker
    else builtins.getAttr latestDockerAttr pkgs;
in
lib.mkIf features.virtualisation {
  virtualisation.docker = {
    enable = true;
    package = lib.mkDefault latestDockerPackage;
  };
}
