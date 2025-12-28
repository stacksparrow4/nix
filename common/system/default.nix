{ config, ... }:

{
  imports = [
    ./audio.nix
    ./display.nix
    ./fonts.nix
    ./nix-config.nix
    ./virt.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  programs._1password.enable = true;
  programs._1password-gui.enable = true;

  programs.wireshark.enable = true;

  # Place home-files in a place that can easily be mounted by docker
  environment.etc."hm-package" = {
    source = config.home-manager.users.sprrw.home.activationPackage;
  };

  systemd.coredump.enable = false;
}
