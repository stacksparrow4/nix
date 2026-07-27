{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.sprrw.ai.llama = {
    enable = lib.mkEnableOption "llama-cpp server";

    context = lib.mkOption {
      type = lib.types.int;
      default = 32768;
      description = "Default context size, can be overridden with llama-server --context";
    };

    models = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Model name, as exposed by the server";
            };

            path = lib.mkOption {
              type = lib.types.path;
              description = "GGUF file for this model";
            };
          };
        }
      );
      default = [ ];
    };
  };

  config =
    let
      cfg = config.sprrw.ai.llama;
    in
    lib.mkIf cfg.enable {
      home.packages = [
        (import ../../../pkgs/llama-server {
          inherit pkgs;
          inherit (inputs) crane;
          inherit (cfg) models context;
        })
      ];
    };
}
