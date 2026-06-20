{
  pkgs,
  lib,
  config,
  mkSandbox,
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

    networkLocalModels = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            pname = lib.mkOption { type = lib.types.str; };
            host = lib.mkOption { type = lib.types.str; };
            model = lib.mkOption { type = lib.types.str; };
            context = lib.mkOption { type = lib.types.int; };
          };
        }
      );
      default = [ ];
    };

    localContext = lib.mkOption {
      type = lib.types.int;
    };
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
      # defaultExtensions = [
      #   "ask-mode.ts"
      #   "hide-bash-body.ts"
      # ];
      # defaultSandboxOptions = {
      #   inherit pkgs config mkSandbox;
      #   extraModels = cfg.extraModels;
      #   extensions = defaultExtensions;
      # };
      # createPiSandbox = import ./pi-sandbox.nix;
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

      home.file.".pi/agent/system".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system";

      home.file.".pi/agent/skills".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/skills";

      home.file.".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions";

      home.packages = [
        (
          let
            pi-boxed = import ../../../../pkgs/pi-boxed { inherit pkgs; };
          in
          pkgs.runCommand "pi-boxed" { } ''
            mkdir -p "$out/bin"
            ln -s "${pi-boxed}/bin/pi-boxed" "$out/bin/pi"
          ''
        )
        (
          let
            pi = import ../../../../pkgs/pi { inherit pkgs; };
          in
          pkgs.runCommand "pi-unsandboxed" { } ''
            mkdir -p "$out/bin"
            ln -s "${pi}/bin/pi" "$out/bin/pi-unsandboxed"
          ''
        )
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
