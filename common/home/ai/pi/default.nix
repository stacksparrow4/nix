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
            Provide only bash commands in plain text, without any markdown formatting. If there is a lack of details, provide most logical solution.
          '';
        })
        (import ./pi-exec.nix {
          inherit pkgs;
          name = "pi-exec-pwsh";
          model = cfg.execModel;
          system = ''
            Provide only PowerShell commands in plain text, without any markdown formatting. If there is a lack of details, provide most logical solution.
          '';
        })
        (import ./pi-remote.nix { inherit pkgs; })
      ];

      # home.packages =
      #   (builtins.map (opts: createPiSandbox (defaultSandboxOptions // opts)) (
      #     [
      #       {
      #         name = "pi";
      #         system = "system-code.md";
      #         braveSearch = true;
      #         shareCwd = true;
      #         network = true;
      #       }
      #       {
      #         name = "pi-chat";
      #         system = "system-chat.md";
      #         braveSearch = true;
      #         network = true;
      #       }
      #       {
      #         name = "pi-tmp";
      #         system = "system-code.md";
      #         braveSearch = true;
      #         network = true;
      #       }
      #       {
      #         name = "pi-local";
      #         system = "system-local.md";
      #         shareCwd = true;
      #         network = false;
      #       }
      #     ]
      #     ++ (builtins.map (hostForward: {
      #       name = hostForward.pname;
      #       system = "system-local.md";
      #       shareCwd = true;
      #       network = false;
      #       inherit hostForward;
      #     }) cfg.networkLocalModels)
      #   ))
      #   ++ [
      #     (import ./pi-remote.nix {
      #       inherit
      #         pkgs
      #         config
      #         mkSandbox
      #         defaultExtensions
      #         ;
      #       extraModels = cfg.extraModels;
      #     })
      #     (import ./pi-exec.nix {
      #       inherit
      #         pkgs
      #         config
      #         mkSandbox
      #         ;
      #       name = "pi-exec";
      #       extraModels = cfg.extraModels;
      #       model = cfg.execModel;
      #       system = "system-exec.md";
      #     })
      #     (import ./pi-exec.nix {
      #       inherit
      #         pkgs
      #         config
      #         mkSandbox
      #         ;
      #       name = "pi-exec-pwsh";
      #       extraModels = cfg.extraModels;
      #       model = cfg.execModel;
      #       system = "system-exec-pwsh.md";
      #     })
      #     (import ./pi-convert.nix {
      #       inherit
      #         pkgs
      #         config
      #         mkSandbox
      #         ;
      #       name = "pi-convert";
      #       extraModels = cfg.extraModels;
      #       model = cfg.execModel;
      #     })
      #   ];
    };
}
