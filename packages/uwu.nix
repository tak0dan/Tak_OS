# Tak_OS · uwu.nix — packages installed only when features.uwuPackages = true
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Package source credit: yunfachi/NixOwOS (MIT licence)
#   https://github.com/yunfachi/NixOwOS
{ pkgs }:

with pkgs; [

  # CatgirlDownloader — GTK4 app that downloads catgirl images from nekos.moe
  # See packages/catgirldownloader.nix for the full derivation + image-size fix.
  (callPackage ./catgirldownloader.nix { })

]
