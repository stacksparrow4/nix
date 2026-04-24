{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.ai.pi = {
    enable = lib.mkEnableOption "pi";
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
      pi = pkgs.pi-coding-agent.overrideAttrs rec {
        version = "0.70.2";
        src = pkgs.fetchFromGitHub {
          owner = "badlogic";
          repo = "pi-mono";
          tag = "v${version}";
          hash = "sha256-qqmJloTp3mWuZBGgpwoyoFyXx6QD8xhJEwCZb7xFabM=";
        };
        npmDeps = pkgs.fetchNpmDeps {
          name = "pi-mono-${version}-npm-deps";
          inherit src;
          hash = "sha256-ImDvTC0Nm+IGYJuqjwUUfnOtA65uJvjlpP4h2Xt/2vE=";
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
              ollama = {
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
        );
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
