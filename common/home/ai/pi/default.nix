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

    execModel = lib.mkOption {
      type = lib.types.str;
    };

    localContext = lib.mkOption {
      type = lib.types.int;
    };
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
    in
    lib.mkIf cfg.enable {
      home.file.".pi/agent/models.json".text = builtins.toJSON {
        providers = {
          local-llama = {
            baseUrl = "http://localhost:8033/v1";
            api = "openai-completions";
            apiKey = "llama";
            models = [
              {
                id = "local";
                contextWindow = cfg.localContext;
              }
            ];
          };
        }
        // cfg.extraModels;
      };

      home.file.".pi/agent/skills".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/skills";

      home.file.".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions";

      home.packages = [
        (import ../../../../pkgs/pi-boxed { inherit pkgs; })
        (import ./pi-convert.nix {
          inherit pkgs;
          model = cfg.execModel;
        })
        (import ./pi-exec.nix {
          inherit pkgs;
          name = "pi-exec";
          model = cfg.execModel;
          system = ''
            Provide a bash command in plain text. Do not provide any description. Do not provide code block formatting. Only output the command. If there is a lack of details, provide most logical solution.
          '';
        })
        (import ./pi-exec.nix {
          inherit pkgs;
          name = "pi-exec-pwsh";
          model = cfg.execModel;
          # TODO: fix
          system = ''
            Provide a PowerShell command in plain text, without any markdown formatting. Do not provide any description, only the command. If there is a lack of details, provide most logical solution.
          '';
        })
      ];
    };
}
