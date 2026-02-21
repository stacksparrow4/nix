{ pkgs, lib, config, ... }:

{
  imports = [
    ../../../common/home
  ];


  sprrw = {
    linux.enable = true;
    nvim.enable = true;
    programming.enable = true;
    programming.sage.enable = lib.mkForce true;
    sec.enable = true;
    term.enable = true;
    gui.enable = true;
    sandboxing.enable = false;
    docker-config.enable = true;
  };

  home = {
    packages = with pkgs; [
      signal-desktop-bin
      lmms
      audacity
      aseprite
    ];

    username = "sprrw";
    homeDirectory = "/home/sprrw";

    file.".background-image".source = ../bg.png;

    file.".config/sway/conf.d/nest01".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/sway.config";
    file.".config/kanshi/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/kanshi.config";
  };
}
