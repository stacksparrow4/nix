{
  inputs,
  config,
  moduleWithSystem,
  ...
}:

let
  nixosModules = config.flake.nixosModules;
  homeModules = config.flake.homeModules;
in
{
  flake.nixosConfigurations.nest01 = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.home-manager.nixosModules.home-manager

      (moduleWithSystem (
        { self', ... }:
        { lib, config, ... }:
        {
          imports = with nixosModules; [
            ./_hardware-configuration.nix
            base
            workstation
            locale
            nix-config
            users
            virt
            tailscale
          ];

          home-manager.users.sprrw =
            { pkgs, config, ... }:
            let
              asepritePkgs =
                import
                  (fetchTarball {
                    url = "https://github.com/NixOS/nixpkgs/archive/4e92bbcdb030f3b4782be4751dc08e6b6cb6ccf2.tar.gz";
                    sha256 = "sha256:1mrf745k78ivw11rj1qibgwi966a83lcljc62p4qix25m1ignirq";
                  })
                  {
                    system = pkgs.stdenv.hostPlatform.system;
                    config = import ../../../nixpkgs-config.nix;
                  };

              repo = "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/hosts/nest01";
            in
            {
              imports = with homeModules; [
                base
                general
                general-linux
                misc
                payloads
                sandbox

                term
                term-yazi-linux
                linux
                nvim

                programming
                programming-sage

                sec
                sec-gui

                gui
                gui-signal
                gui-lmms

                ai
                ai-llama
                ai-pi
              ];

              sprrw = {
                ai = {
                  # https://aistudio.google.com/app/api-keys
                  pi.execModel = "gemini-3.6-flash";

                  llama = {
                    models = [
                      {
                        name = "qwen3.5";
                        path = pkgs.fetchurl {
                          url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-UD-Q3_K_XL.gguf";
                          hash = "sha256-quCHnhvpnOk/DVYhf4GFo5niWtaKjrvAlfNicGKDBi8=";
                        };
                        options = {
                          ctx-size = 16384;
                          flash-attn = "on";
                          cache-type-k = "q8_0";
                          cache-type-v = "q8_0";
                        };
                      }
                      {
                        name = "qwen3.6";
                        path = pkgs.fetchurl {
                          url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
                          hash = "sha256-rA4sEYngVfqjbv82FYDnnFvW+Odr/7TOVH8WfVPjGmE=";
                        };
                        options = {
                          ctx-size = 16384;
                          n-cpu-moe = 999;
                          n-gpu-layers = 999;
                          threads = 6;
                          flash-attn = "on";
                          cache-type-k = "q8_0";
                          cache-type-v = "q8_0";
                        };
                      }
                      {
                        name = "swift";
                        path = pkgs.fetchurl {
                          url = "https://huggingface.co/ukisai/Swift-Qwen3.8-27B-GGUF/resolve/main/Swift-Qwen3.8-27B-Q4_K_M.gguf";
                          hash = "sha256-rVgR4pFDG9DeHOwMQASl6smNrumFCILtrGmoIyCeiKs=";
                        };
                        options = {
                          ctx-size = 8192;
                          spec-type = "draft-mtp";
                          spec-draft-n-max = 2;
                          threads = 6;
                          flash-attn = "on";
                          cache-type-k = "q8_0";
                          cache-type-v = "q8_0";
                        };
                      }
                    ];
                  };
                };
              };

              home = {
                username = "sprrw";
                homeDirectory = "/home/sprrw";

                packages = [
                  asepritePkgs.aseprite
                ]
                ++ (with pkgs; [
                  audacity
                  prismlauncher
                ])
                ++ (with self'.packages; [
                  sprrw
                ]);

                file.".background-image".source = ./bg.png;

                file.".config/sway/conf.d/nest01".source =
                  config.lib.file.mkOutOfStoreSymlink "${repo}/sway.config";
                file.".config/kanshi/config".source = config.lib.file.mkOutOfStoreSymlink "${repo}/kanshi.config";
                file.".ssh/config".source = config.lib.file.mkOutOfStoreSymlink "${repo}/ssh.config";
                file.".config/noctalia/nest01.toml".source =
                  config.lib.file.mkOutOfStoreSymlink "${repo}/noctalia.toml";
              };
            };

          sprrw.flatpaks = [
            {
              name = "org.musescore.MuseScore";
            }
          ];

          nix.extraOptions = ''
            builders = ssh-ng://root@stacksparrow4 aarch64-linux
          '';

          programs.steam = {
            enable = true;
          };

          nixpkgs.config = import ../../../nixpkgs-config.nix;

          boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

          boot.loader.timeout = lib.mkForce 9999;

          swapDevices = [
            {
              device = "/swapfile";
              size = 32 * 1024;
            }
          ];

          services.fstrim = {
            enable = true;
            interval = "weekly";
          };

          networking.hostName = "nest01";

          hardware.graphics = {
            enable = true;
          };
          hardware.nvidia = {
            modesetting.enable = true;
            powerManagement.enable = false;
            powerManagement.finegrained = false;
            open = false;
            nvidiaSettings = true;
            package = config.boot.kernelPackages.nvidiaPackages.stable;
          };
          services.xserver.videoDrivers = [ "nvidia" ];

          hardware.opentabletdriver.enable = true;
          hardware.opentabletdriver.daemon.enable = true;

          # This value determines the NixOS release from which the default
          # settings for stateful data, like file locations and database
          # versions on your system were taken. It's perfectly fine and
          # recommended to leave this value at the release version of the
          # first install of this system.
          system.stateVersion = "24.11";
        }
      ))
    ];
  };
}
