{ moduleWithSystem, ... }:

{
  flake.homeModules.ai-llama = moduleWithSystem (
    { self', ... }:
    { pkgs, config, lib, ... }:
    let
      cfg = config.sprrw.ai.llama;
    in
    {
      options.sprrw.ai.llama = {
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

      config.home.packages = [
        (pkgs.writeShellApplication {
          name = "llama-server";
          runtimeInputs = [ pkgs.socat ];
          text =
            let
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
            ''
              ${self'.packages.llama-server}/bin/llama-server ${modelsDir} ${toString cfg.context} "$@"
            '';
        })
      ];
    }
  );
}
