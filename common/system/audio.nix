{ pkgs, ... }:

{
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
}
