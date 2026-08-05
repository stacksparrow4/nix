{
  flake.nixosModules.audio =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
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
