{
  inputs,
  config,
  withSystem,
  ...
}:

let
  nixosModules = config.flake.nixosModules;
  homeModules = config.flake.homeModules;
in
{
  flake.nixosModules.gaming = {
    programs.steam = {
      enable = true;
      # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      # localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
  };

  flake.nixosConfigurations.nest01 = withSystem "x86_64-linux" (
    { fetchHF, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.home-manager.nixosModules.home-manager

        {
          imports = with nixosModules; [
            ./_hardware-configuration.nix
            base
            workstation
            gaming
            locale
            nix-config
            users
            virt
          ];
        }

        {
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
                sprrw-cli
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

              sprrw.ai = {
                # https://aistudio.google.com/app/api-keys
                pi.execModel = "gemini-3.6-flash";

                llama = {
                  context = 32768;
                  models = [
                    {
                      name = "qwen3.5";
                      path = pkgs.fetchurl {
                        url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-UD-Q3_K_XL.gguf";
                        hash = "sha256-quCHnhvpnOk/DVYhf4GFo5niWtaKjrvAlfNicGKDBi8=";
                      };
                    }
                    {
                      name = "qwen3.6-27b";
                      path = pkgs.fetchurl {
                        url = "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-UD-IQ3_XXS.gguf";
                        hash = "sha256-XVkd0RkY4Zant8nS8C5DkOcmSWDrNUxy1l6BqTMZePU=";
                      };
                    }
                    {
                      name = "qwen3.6";
                      path = fetchHF {
                        repo = "knoopx/Qwen3.6-35B-A3B-NVFP4-GGUF";
                        filename = "Qwen3.6-35B-A3B-NVFP4.gguf";
                        revision = "b1bb81d83149a74fc9c7179b539a796d93f18820";
                        hash = "sha256-wTWOiAjrdpWzZN4w6ExBWAFlaDg5JXglBSTDt/3dGQY=";
                      };
                    }
                  ];
                };
              };

              home = {
                username = "sprrw";
                homeDirectory = "/home/sprrw";

                packages = [
                  pkgs.audacity
                  asepritePkgs.aseprite
                  pkgs.prismlauncher
                ];

                file.".background-image".source = ./bg.png;

                file.".config/sway/conf.d/nest01".source =
                  config.lib.file.mkOutOfStoreSymlink "${repo}/sway.config";
                file.".config/kanshi/config".source = config.lib.file.mkOutOfStoreSymlink "${repo}/kanshi.config";
                file.".ssh/config".source = config.lib.file.mkOutOfStoreSymlink "${repo}/ssh.config";
                file.".config/noctalia/nest01.toml".source =
                  config.lib.file.mkOutOfStoreSymlink "${repo}/noctalia.toml";
              };

              nix.extraOptions = ''
                builders = ssh-ng://root@ssh.stacksparrow4.xyz aarch64-linux /home/sprrw/.ssh/stacksparrow4
              '';
            };
        }

        (
          { lib, config, ... }:
          {
            nixpkgs.config = import ../../../nixpkgs-config.nix;

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
            networking.extraHosts = ''
              192.9.173.108 kubernetes.default
            '';

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
        )
      ];
    }
  );
}
