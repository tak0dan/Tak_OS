# Tak_OS · audio.nix — PipeWire audio stack (ALSA + PulseAudio compat + rtkit)
# github.com/tak0dan/Tak_OS · GNU GPLv3
{ config, pkgs, ... }:

{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
}
