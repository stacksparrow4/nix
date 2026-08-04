{
  pkgs,
  lib,
  config,
  self',
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

      modelsDir = pkgs.linkFarm "llama-models" (
        map (
          { name, path }:
          {
            name = "${name}.gguf";
            inherit path;
          }
        ) cfg.models
      );
    in
    lib.mkIf cfg.enable {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "llama-server";
          runtimeInputs = [ pkgs.socat ];
          text = ''
            ${self'.packages.llama-server}/bin/llama-server ${modelsDir} ${toString cfg.context} "$@"
          '';
        })
      ];
    };
}
