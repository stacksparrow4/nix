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
      pi = import ../../../../pkgs/pi { inherit pkgs; };
      createPiSandbox =
        {
          name,
          tools ? [
            "read"
            "write"
            "edit"
            "bash"
          ],
          system,
          braveSearch ? false,
          # Settings are locked down by defualt
          shareCwd ? false,
          network ? false,
        }:
        (config.sprrw.sandbox.create {
          inherit name;
          sharedPaths = [
            {
              hostPath = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions";
              boxPath = "/home/sprrw/.pi/agent/extensions";
              ro = true;
              type = "dir";
            }
            {
              hostPath = "$HOME/.pi/agent/settings.json";
              boxPath = "/home/sprrw/.pi/agent/settings.json";
              ro = false;
              type = "file";
            }
            {
              hostPath = pkgs.writeText "pi-models" (
                builtins.toJSON {
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
                                id = "llama";
                                contextWindow = config.sprrw.ai.llama-cpp.context;
                              }
                            ];
                          };
                        }
                      else
                        { }
                    )
                    // cfg.extraModels;
                }
              );
              boxPath = "/home/sprrw/.pi/agent/models.json";
              ro = true;
              type = "file";
            }
            {
              hostPath = system;
              boxPath = "/home/sprrw/.pi/agent/SYSTEM.md";
              ro = true;
              type = "file";
            }
          ]
          ++ (
            if network then
              [
                {
                  hostPath = "$HOME/.pi/agent/auth.json";
                  boxPath = "/home/sprrw/.pi/agent/auth.json";
                  ro = false;
                  type = "file";
                }
              ]
            else
              [
                {
                  hostPath = "/tmp/llama-cpp";
                  boxPath = "/tmp/llama-cpp";
                  ro = true;
                  type = "dir";
                }
              ]
          )
          ++ (
            if braveSearch then
              [
                {
                  hostPath = "$HOME/.config/brave-search";
                  boxPath = "/home/sprrw/.config/brave-search";
                  ro = true;
                  type = "dir";
                }
              ]
            else
              [ ]
          );
          downgradeTerm = true;
          stdin = true;
          tty = true;
          inherit shareCwd network;
          hostNetwork = network;
          prog = "${
            pkgs.writeShellApplication {
              name = "pi";
              text = ''
                ${
                  if network then
                    ""
                  else
                    "socat TCP-LISTEN:8033,reuseaddr,fork UNIX-CONNECT:/tmp/llama-cpp/llama.sock &"
                }

                ${pi}/bin/pi \
                  --no-tools --tools ${builtins.concatStringsSep "," tools} \
                  ${if network then "" else "--models llama"} \
                  "$@"
              '';
            }
          }/bin/pi";
        });
    in
    lib.mkIf cfg.enable {
      home.packages = [
        (createPiSandbox {
          name = "pi";
          system = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-code.md";
          braveSearch = true;
          shareCwd = true;
          network = true;
        })
        (createPiSandbox {
          name = "pi-tmp";
          system = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-code.md";
          braveSearch = true;
          network = true;
        })
        (createPiSandbox {
          name = "pi-chat";
          system = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-chat.md";
          braveSearch = true;
          tools = [ "bash" ];
          network = true;
        })
        (createPiSandbox {
          name = "pi-local";
          system = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-local.md";
          shareCwd = true;
          network = false;
        })
        (createPiSandbox {
          name = "pi-local-tmp";
          system = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-local.md";
          network = false;
        })
      ];
    };
}
