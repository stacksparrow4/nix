{ pkgs, ... }:

{
  imports = [
     ../../../common/home
  ];

  home = {
    username = "root";
    homeDirectory = "/root";
  };

  sprrw.useAllEnvironments = false;
  
  sprrw.rofi.enable = false;
  sprrw.alacritty.enable = false;

  home.file.".config/nix/nix.conf".text = ''
    extra-experimental-features = flakes nix-command
  '';

  sprrw.bashPS1 = ''\n\[\033[1;34m\] \W \$\[\033[0m\] '';

  sprrw.packages = {
    installGuiPackages = false;
    installLinuxPackages = true;
  };

  home.packages = with pkgs; [
    coreutils
    curl
    nix
    which
    cacert
    iputils
    iproute2
    ps
  ];
}
