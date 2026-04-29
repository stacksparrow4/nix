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
        version = "0.70.6";
        src = pkgs.fetchFromGitHub {
          owner = "badlogic";
          repo = "pi-mono";
          tag = "v${version}";
          hash = "sha256-XZUnKk+B9kWn51kRfMkfInYCz+5hVuWQBvgOm9PO9bo=";
        };
        npmDeps = pkgs.fetchNpmDeps {
          name = "pi-mono-${version}-npm-deps";
          inherit src;
          hash = "sha256-pEVIqp9rbuHFE6eqSmADmIXWAPey1VbD7qmOJwksz1o=";
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
