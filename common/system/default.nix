{ pkgs, ... }:

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

  programs._1password = {
    package = pkgs._1password-cli;
    enable = true;
  };
  programs._1password-gui = {
    package = pkgs._1password-gui;
    enable = true;
  };

  programs.wireshark.enable = true;
}
