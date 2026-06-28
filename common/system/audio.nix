{
  pkgs,
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (!config.sprrw.headless) {
    environment.systemPackages = with pkgs; [
      pavucontrol
      pasystray
      pulseaudio
      playerctl
    ];

    services.pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
  };
}
