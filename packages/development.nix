# Tak_OS · development.nix — Compilers, debuggers, and dev toolchains
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs }:


with pkgs; [


  # =========================
  # Containers
  # =========================

  # =========================
  # Databases
  # =========================
  # -- RELATIONAL
  # -- NO-RELATIONAL
  # mongodb
  # mongodb-compass


  # =========================
  # Diagramming & Office
  # =========================
  dia
  libreoffice-still


  # =========================
  # Text Editors
  # =========================

  kdePackages.kate


  # =========================
  # Eclipse IDEs
  # =========================
  eclipse-mat
  eclipses.eclipse-committers
  eclipses.eclipse-cpp
  eclipses.eclipse-dsl
  eclipses.eclipse-embedcpp
  eclipses.eclipse-java
  eclipses.eclipse-jee
  eclipses.eclipse-modeling
  eclipses.eclipse-platform
  eclipses.eclipse-rcp
  eclipses.eclipse-sdk


  # =========================
  # JetBrains IDEs
  # =========================
  # jetbrains.clion
  # jetbrains.idea
  # jetbrains.pycharm


  # =========================
  # Whatever this shit is
  # =========================
  awscli2
  #xampp


  # =========================
  # JavaScript / Node.js
  # =========================
  nodejs
  pnpm
  openjdk21


  # =========================
  # Other IDEs & Editors
  # =========================
  netbeans
  neovim
  vim
  vscode
  # vscodium


  # =========================
  # Perl
  # =========================
  perlPackages.PlackMiddlewareFixMissingBodyInRedirect


  # =========================
  # Python
  # =========================
  python3
  python313Packages.ifconfig-parser
  python313Packages.pip
  python314Packages.ifconfig-parser


  # =========================
  # AI
  # =========================
  # OpenCode comes from nixpkgs-unstable rather than
  # the NixOS 26.05 package set.
  
  
  opencode
  codex
]

