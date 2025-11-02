{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pavucontrol
    pasystray
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
