# Tak_OS · development.nix — Compilers, debuggers, and dev toolchains
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ pkgs }:

with pkgs; [

  # =========================
  # Containers
  # =========================
  docker          # Container runtime and tooling

  # =========================
  # Databases
  # =========================
  mariadb         # MySQL-compatible relational database server
  mysql-workbench # GUI client and admin tool for MySQL / MariaDB

  # =========================
  # Diagramming & Office
  # =========================
  dia               # Vector diagram editor (UML, flowcharts, ER, …)
  libreoffice-still # LibreOffice — stable branch office suite

  # =========================
  # Eclipse IDEs
  # =========================
  eclipse-mat                   # Eclipse Memory Analyzer Tool
  eclipses.eclipse-committers   # Eclipse for committers (general-purpose plug-in dev)
  eclipses.eclipse-cpp          # Eclipse CDT — C/C++ development
  eclipses.eclipse-dsl          # Eclipse with DSL / Xtext support
  eclipses.eclipse-embedcpp     # Eclipse for embedded C/C++ (MCU plug-in)
  eclipses.eclipse-java         # Eclipse IDE for Java development
  eclipses.eclipse-jee          # Eclipse IDE for Java EE / Jakarta EE
  eclipses.eclipse-modeling     # Eclipse Modeling Framework (EMF / GMF)
  eclipses.eclipse-platform     # Eclipse base platform (minimal headless)
  eclipses.eclipse-rcp          # Eclipse Rich Client Platform
  eclipses.eclipse-sdk          # Eclipse SDK with source and developer tools

  # =========================
  # JetBrains IDEs
  # =========================
  jetbrains.clion     # C / C++ IDE
  jetbrains.idea      # IntelliJ IDEA — Java / Kotlin / Android
  jetbrains.pycharm   # Python IDE

  # =========================
  # JavaScript / Node.js
  # =========================
  nodejs   # JavaScript runtime (LTS)
  pnpm     # Fast, disk-efficient Node package manager

  # =========================
  # Other IDEs & Editors
  # =========================
  netbeans  # Apache NetBeans IDE (Java / PHP / HTML)
  neovim    # Extensible Vim-based editor
  vim       # Classic Vi-compatible editor
  vscode    # Visual Studio Code
  # vscodium  # VSCode without Microsoft telemetry (uncomment to use)

  # =========================
  # Perl
  # =========================
  perl5Packages.PlackMiddlewareFixMissingBodyInRedirect  # PSGI middleware — fix missing body in redirects

  # =========================
  # Python
  # =========================
  python3                            # Python 3 interpreter (default version)
  python313Packages.ifconfig-parser  # ifconfig output parser — Python 3.13
  python313Packages.pip              # pip package installer — Python 3.13
  python314Packages.ifconfig-parser  # ifconfig output parser — Python 3.14

]
