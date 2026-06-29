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
    payloads.enable = true;
  };

  home = {
    packages =
      with pkgs;
      [
        audacity
        aseprite
        prismlauncher
        ares
      ]
      ++ (
        let
          qwen35 = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-UD-Q3_K_XL.gguf";
            hash = "sha256-quCHnhvpnOk/DVYhf4GFo5niWtaKjrvAlfNicGKDBi8=";
          };
          qwen36 = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-UD-IQ3_XXS.gguf";
            hash = "sha256-XVkd0RkY4Zant8nS8C5DkOcmSWDrNUxy1l6BqTMZePU=";
          };
        in
        [
          (mkLlama {
            name = "qwen3.5-reasoning";
            model = qwen35;
            context = 32768;
            reasoning = true;
          })
          (mkLlama {
            name = "qwen3.5";
            model = qwen35;
            context = 32768;
            reasoning = false;
          })
          (mkLlama {
            name = "qwen3.6-reasoning";
            model = qwen36;
            context = 32768;
            reasoning = true;
          })
          (mkLlama {
            name = "qwen3.6";
            model = qwen36;
            context = 32768;
            reasoning = false;
          })
        ]
      );

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
