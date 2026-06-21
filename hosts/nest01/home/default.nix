{
  pkgs,
  lib,
  config,
  mkLlama,
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
      pi = {
        enable = true;
        execModel = "local";
        localContext = 32768;
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
      lmms.enable = true;
    };
  };

  home = {
    packages = with pkgs; [
      audacity
      aseprite
      prismlauncher
      ares

      (mkLlama {
        name = "qwen3.5";
        model = pkgs.fetchurl {
          url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-UD-Q3_K_XL.gguf";
          hash = "sha256-quCHnhvpnOk/DVYhf4GFo5niWtaKjrvAlfNicGKDBi8=";
        };
        context = 32768;
      })
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
