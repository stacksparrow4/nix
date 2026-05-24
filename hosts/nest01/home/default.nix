{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ../../../common/home
  ];

  sprrw = {
    misc.enable = true;
    sandbox.enable = true;
    ai = {
      enable = true;
      qwen.enable = true;
      llama-cpp = {
        enable = true;
        # context = 32768;
        context = 65536;
      };
      pi = {
        enable = true;
        execModel = "llama";
      };
    };
    linux.enable = true;
    nvim.enable = true;
    programming.enable = true;
    programming.sage.enable = lib.mkForce true;
    sec.enable = true;
    term.enable = true;
    gui = {
      enable = true;
      signal.enable = true;
    };
  };

  home = {
    packages = with pkgs; [
      lmms-full
      audacity
      aseprite
      prismlauncher
      ares
    ];

    username = "sprrw";
    homeDirectory = "/home/sprrw";

    file.".background-image".source = ../bg.png;

    file.".config/sway/conf.d/nest01".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/sway.config";
    file.".config/kanshi/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/kanshi.config";

    file.".ssh/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/ssh.config";
  };
}
