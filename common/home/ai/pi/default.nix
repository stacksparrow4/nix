{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.pi = {
    enable = lib.mkEnableOption "pi";

    extraModels = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
      pi = pkgs.pi-coding-agent.overrideAttrs rec {
        version = "0.71.0";
        src = pkgs.fetchFromGitHub {
          owner = "badlogic";
          repo = "pi-mono";
          tag = "v${version}";
          hash = "sha256-SDfA+dKW7dCUMp0sjcB7B3gnX+0hcoNROREUH+aSTMo=";
        };
        npmDeps = pkgs.fetchNpmDeps {
          name = "pi-mono-${version}-npm-deps";
          inherit src;
          hash = "sha256-3W2YMBaUe704Y78Zw13o9dC9lwwHri+4OwFwCpq2drA=";
        };
      };
      piArgs = {
        sharedPaths = [
          {
            hostPath = "$HOME/.pi";
            boxPath = "/home/sprrw/.pi";
            ro = false;
            type = "dir";
          }
          {
            hostPath = "$HOME/.config/brave-search";
            boxPath = "/home/sprrw/.config/brave-search";
            ro = true;
            type = "dir";
          }
        ];
        downgradeTerm = true;
        stdin = true;
        tty = true;
        network = true;
        hostNetwork = true;
        prog = "${pi}/bin/pi";
      };
    in
    lib.mkIf cfg.enable {
      home.file.".pi/agent/models.json".text = builtins.toJSON {
        providers = (
          if config.sprrw.ai.llama-cpp.enable then
            {
              llama = {
                baseUrl = "http://localhost:8033/v1";
                api = "openai-completions";
                apiKey = "llama";
                models = [
                  {
                    id = "default";
                    contextWindow = config.sprrw.ai.llama-cpp.context;
                  }
                ];
              };
            }
          else
            { }
        ) // cfg.extraModels;
      };

      home.file.".pi/agent/SYSTEM.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system.md";

      home.file.".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions";

      home.packages = lib.mkMerge [
        [
          (config.sprrw.sandbox.create (
            piArgs
            // {
              name = "pi-tmp";
            }
          ))
          (config.sprrw.sandbox.create (
            piArgs
            // {
              name = "pi";
              shareCwd = true;
            }
          ))
        ]
      ];
    };
}
