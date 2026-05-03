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
      default = { };
    };
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
      pi = pkgs.pi-coding-agent.overrideAttrs rec {
        version = "0.72.1";
        src = pkgs.fetchFromGitHub {
          owner = "badlogic";
          repo = "pi-mono";
          tag = "v${version}";
          hash = "sha256-SqUxghc60P3HfmaFJGB/m23mvzw0cD7cDEUrNFOqo0Y=";
        };
        npmDeps = pkgs.fetchNpmDeps {
          name = "pi-mono-${version}-npm-deps";
          inherit src;
          hash = "sha256-KUC1xQK6oJXtg962YeLOnO76uTdR10/VNa9iiCdT3VM=";
        };
      };
      createPiMount =
        {
          path,
          ro,
          type,
        }:
        {
          hostPath = "$HOME/.pi/agent/${path}";
          boxPath = "/home/sprrw/.pi/agent/${path}";
          inherit ro type;
        };
      piArgs = additionalSharedPaths: {
        sharedPaths =
          (builtins.map createPiMount [
            {
              path = "auth.json";
              ro = false;
              type = "file";
            }
            {
              path = "extensions";
              ro = true;
              type = "dir";
            }
            {
              path = "models.json";
              ro = true;
              type = "file";
            }
            {
              path = "settings.json";
              ro = false;
              type = "file";
            }
          ])
          ++ [
            {
              hostPath = "$HOME/.config/brave-search";
              boxPath = "/home/sprrw/.config/brave-search";
              ro = true;
              type = "dir";
            }
          ]
          ++ additionalSharedPaths;
        downgradeTerm = true;
        stdin = true;
        tty = true;
        network = true;
        hostNetwork = true;
        prog = "${pi}/bin/pi";
      };
    in
    lib.mkIf cfg.enable {
      # All the home.file can technically be forwarded directly to sandbox but this is done so that
      #  ~/.pi exists on the host so it is easy to look at if required
      home.file.".pi/agent/models.json".text = builtins.toJSON {
        providers =
          (
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
          )
          // cfg.extraModels;
      };

      home.file.".pi/agent/system-code.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-code.md";
      home.file.".pi/agent/system-chat.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-chat.md";

      home.file.".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions";

      home.packages =
        let
          piArgsWithSystem =
            fname:
            piArgs [
              {
                hostPath = "$HOME/.pi/agent/${fname}";
                boxPath = "/home/sprrw/.pi/agent/SYSTEM.md";
                ro = true;
                type = "file";
              }
            ];
        in
        lib.mkMerge [
          [
            (config.sprrw.sandbox.create (
              (piArgsWithSystem "system-code.md")
              // {
                name = "pi";
                shareCwd = true;
              }
            ))
            (config.sprrw.sandbox.create (
              (piArgsWithSystem "system-code.md")
              // {
                name = "pi-tmp";
              }
            ))
            (config.sprrw.sandbox.create (
              (piArgsWithSystem "system-chat.md")
              // {
                name = "pi-chat";
                prog = "${pi}/bin/pi --no-tools --tools bash";
              }
            ))
          ]
        ];
    };
}
