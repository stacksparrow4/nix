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

                ai
                ai-llama
                ai-pi
                ai-llama-qwen
              ];

              sprrw = {
                ai = {
                  pi.execModel = "gpt-5.6-terra";
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

          services.flatpak = {
            packages = [
              {
                appId = "org.musescore.MuseScore";
                origin = "flathub";
              }
              {
                appId = "org.signal.Signal";
                origin = "flathub";
              }
              {
                appId = "org.prismlauncher.PrismLauncher";
                origin = "flathub";
              }
            ];

            overrides = {
              "org.musescore.MuseScore".Context = {
                sockets = [ "!cups" ];
              };
              "org.signal.Signal".Context = {
                shared = [ "!ipc" ];
                sockets = [ "!fallback-x11" ];
              };
              "org.prismlauncher.PrismLauncher".Context = {
                filesystems = [
                  "!xdg-run/app/com.discordapp.Discord"
                  "!xdg-download"
                  "!~/.ftba"
                ];
              };
            };
          };

          nix.extraOptions = ''
            builders = ssh-ng://root@stacksparrow4 aarch64-linux
          '';

          nixpkgs.config = import ../../../nixpkgs-config.nix;

          boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

          boot.loader.timeout = lib.mkForce 9999;

          boot.loader.efi.efiSysMountPoint = "/efi";
          boot.loader.systemd-boot.xbootldrMountPoint = "/boot";

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
