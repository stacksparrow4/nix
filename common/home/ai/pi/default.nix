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
      type = lib.types.listOf (lib.types.submodule {
        options = {
          pname = lib.mkOption { type = lib.types.str; };
          host = lib.mkOption { type = lib.types.str; };
          model = lib.mkOption { type = lib.types.str; };
          context = lib.mkOption { type = lib.types.int; };
        };
      });
      default = [ ];
    };
  };

  config =
    let
      cfg = config.sprrw.ai.pi;
      defaultExtensions = [
        "ask-mode.ts"
        "hide-bash-body.ts"
      ];
      defaultSandboxOptions = {
        inherit pkgs config mkSandbox;
        extraModels = cfg.extraModels;
        extensions = defaultExtensions;
      };
      createPiSandbox = import ./pi-sandbox.nix;
    in
    lib.mkIf cfg.enable {
      home.packages =
        (builtins.map (opts: createPiSandbox (defaultSandboxOptions // opts)) (
          [
            {
              name = "pi";
              system = "system-code.md";
              braveSearch = true;
              shareCwd = true;
              network = true;
            }
            {
              name = "pi-chat";
              system = "system-chat.md";
              braveSearch = true;
              network = true;
            }
            {
              name = "pi-tmp";
              system = "system-code.md";
              braveSearch = true;
              network = true;
            }
            {
              name = "pi-local";
              system = "system-local.md";
              shareCwd = true;
              network = false;
            }
          ]
          ++ (builtins.map (hostForward: {
            name = hostForward.pname;
            system = "system-local.md";
            shareCwd = true;
            network = false;
            inherit hostForward;
          }) cfg.networkLocalModels)
        ))
        ++ [
          (import ./pi-remote.nix {
            inherit
              pkgs
              config
              mkSandbox
              defaultExtensions
              ;
            extraModels = cfg.extraModels;
          })
          (import ./pi-exec.nix {
            inherit
              pkgs
              config
              mkSandbox
              ;
            name = "pi-exec";
            extraModels = cfg.extraModels;
            execModel = cfg.execModel;
            system = "system-exec.md";
          })
          (import ./pi-exec.nix {
            inherit
              pkgs
              config
              mkSandbox
              ;
            name = "pi-exec-pwsh";
            extraModels = cfg.extraModels;
            execModel = cfg.execModel;
            system = "system-exec-pwsh.md";
          })
        ];
    };
}
