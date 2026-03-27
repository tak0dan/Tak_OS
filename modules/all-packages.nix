{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    libsecret  # provides secret-tool for keyring access
  ];
}
