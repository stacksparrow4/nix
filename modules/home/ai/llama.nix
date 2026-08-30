{ moduleWithSystem, ... }:

{
  flake.homeModules.ai-llama = moduleWithSystem (
    { self', ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      options.sprrw.ai.llama = {
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

                context = lib.mkOption {
                  type = lib.types.int;
                  description = "Default context size, can be overridden with llama-server --context";
                };

                mtp = lib.mkOption {
                  type = lib.types.int;
                  default = 0;
                  description = "Number of MTP speculative tokens, 0 for no MTP";
                };
              };
            }
          );
          default = [ ];
        };
      };

      config.home.packages =
        let
          cfg = config.sprrw.ai.llama;
          modelsPreset = (pkgs.formats.ini { }).generate "preset.ini" (
            builtins.listToAttrs (
              map (
                {
                  name,
                  context,
                  mtp,
                  ...
                }:
                {
                  inherit name;
                  value = {
                    ctx-size = context;
                  }
                  // (
                    if mtp != 0 then
                      {
                        spec-type = "draft-mtp";
                        spec-draft-n-max = mtp;
                      }
                    else
                      { }
                  );
                }
              ) cfg.models
            )
          );
          modelsDir = pkgs.linkFarm "llama-models" (
            map (
              { name, path, ... }:
              {
                name = "${name}.gguf";
                inherit path;
              }
            ) cfg.models
          );
        in
        [
          (pkgs.writeShellApplication {
            name = "llama-server";
            runtimeInputs = [ pkgs.socat ];
            text = ''
              ${self'.packages.llama-server}/bin/llama-server \
                --internal-models-dir ${modelsDir} \
                --internal-preset-ini ${modelsPreset} \
                "$@"
            '';
          })
        ];
    }
  );
}
