# Tak_OS · zsh.nix — Zsh shell configuration and completions
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    # Optional: only if you want to source a specific user's .zshrc explicitly.
#    interactiveShellInit = ''
#      if [ -f "${config.users.users.<name>.home}/.zshrc" ]; then
#        source "${config.users.users.<name>.home}/.zshrc"
#      fi
#    '';
  };
}
