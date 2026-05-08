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
      defaultExtensions = [
        "ask-mode.ts"
        "hide-tool-bodies.ts"
      ];
      createExtensionMount = extname: {
        hostPath = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/extensions/${extname}";
        boxPath = "/home/sprrw/.pi/agent/extensions/${extname}";
        ro = true;
        type = "file";
      };
      createPiSandbox =
        {
          name,
          tools ? [
            "read"
            "write"
            "edit"
            "bash"
          ],
          extensions ? defaultExtensions,
          system,
          braveSearch ? false,
          # Settings are locked down by defualt
          shareCwd ? false,
          network ? false,
          extraMounts ? [ ],
        }:
        (config.sprrw.sandbox.create {
          inherit name;
          sharedPaths =
            (builtins.map createExtensionMount extensions)
            ++ [
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
            )
            ++ extraMounts;
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
                  --no-tools ${if (builtins.length tools) > 0 then "--tools ${builtins.concatStringsSep "," tools}" else ""} \
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
        (
          let
            pi-remote-script = pkgs.python3Packages.buildPythonApplication {
              pname = "pi-remote";
              version = "0.1.0";

              src = ./pi-remote.py;

              dontUnpack = true;
              format = "other";

              installPhase = ''
                install -D $src $out/bin/pi-remote
              '';
            };
            pi-remote-sandbox = createPiSandbox {
              name = "pi-remote-sandbox";
              system = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/ai/pi/system-remote.md";
              tools = [ "command" ];
              extensions = [ "pi-remote.ts" ]; # TODO: add others and resolve conflicts
              network = true;
              extraMounts = [
                {
                  hostPath = "$PIPEDIR";
                  boxPath = "/tmp/pi-remote";
                  type = "dir";
                  ro = true;
                }
              ];
            };
          in
          pkgs.writeShellApplication {
            name = "pi-remote";
            text = ''
              ${pi-remote-script}/bin/pi-remote ${pi-remote-sandbox}/bin/pi-remote-sandbox "$@"
            '';
          }
        )
      ];
    };
}
