# Tak_OS · eclipse.nix — Eclipse IDE variants
# github.com/tak0dan/Tak_OS · GNU GPLv3
#{ pkgs }:
#
#let
#  myEclipse = pkgs.eclipses.eclipseWithPlugins {
#    eclipse = pkgs.eclipses.eclipse-jee; # pick ONE base
#    jvmArgs = [ "-Xmx2048m" ];
#   plugins = [
#      pkgs.eclipses.plugins.color-theme
#      pkgs.eclipses.plugins.egit
#    ];
#  };
#in
#[
#  myEclipse
#  pkgs.temurin-bin-21   # choose ONE main JDK
#  pkgs.maven
#  pkgs.gradle
#  pkgs.git
#]
