{
  pkgs,
  lib,
  config,
  fetchHF,
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
        execModel = "qwen3.5";
      };
      llama = {
        enable = true;
        context = 32768;
        models = [
          {
            name = "qwen3.5";
            path = pkgs.fetchurl {
              url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-UD-Q3_K_XL.gguf";
              hash = "sha256-quCHnhvpnOk/DVYhf4GFo5niWtaKjrvAlfNicGKDBi8=";
            };
          }
          {
            name = "qwen3.6-27b";
            path = pkgs.fetchurl {
              url = "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-UD-IQ3_XXS.gguf";
              hash = "sha256-XVkd0RkY4Zant8nS8C5DkOcmSWDrNUxy1l6BqTMZePU=";
            };
          }
          {
            name = "qwen3.6";
            path = fetchHF {
              repo = "knoopx/Qwen3.6-35B-A3B-NVFP4-GGUF";
              filename = "Qwen3.6-35B-A3B-NVFP4.gguf";
              revision = "b1bb81d83149a74fc9c7179b539a796d93f18820";
              hash = "sha256-wTWOiAjrdpWzZN4w6ExBWAFlaDg5JXglBSTDt/3dGQY=";
            };
          }
        ];
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
    packages = with pkgs; [
      audacity
      aseprite
      prismlauncher
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

    file.".config/noctalia/nest01.toml".source = 
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/hosts/nest01/home/noctalia.toml";
  };
}
