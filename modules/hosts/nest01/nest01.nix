{
  inputs,
  self,
  ...
}:

{
  flake.nixosConfigurations.nest01 = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.home-manager.nixosModules.home-manager
      ./_hardware-configuration.nix
    ]
    ++ (with self.modules.nixos; [
      base
      workstation
      workstation-virt
      steam
      spotify
      locale
      nix-config
      users
      podman
      tailscale
    ])
    ++ [
      (
        { config, ... }:
        {
          home-manager.users.sprrw =
            { pkgs, config, ... }:
            {
              imports = with self.modules.homeManager; [
                base
                general
                misc
                payloads
                sandbox
                term
                linux
                nvim
                programming
                sec
                sec-gui
                gui
                llama
                pi
                llama-qwen
                sops
                ssh
              ];

              home =
                let
                  nest01Dir = "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/hosts/nest01";
                in
                {
                  packages = with pkgs; [
                    audacity
                  ];

                  file.".background-image".source = ./bg.png;

                  file.".config/sway/conf.d/nest01".source =
                    config.lib.file.mkOutOfStoreSymlink "${nest01Dir}/sway.config";
                  file.".config/kanshi/config".source =
                    config.lib.file.mkOutOfStoreSymlink "${nest01Dir}/kanshi.config";
                  file.".config/noctalia/nest01.toml".source =
                    config.lib.file.mkOutOfStoreSymlink "${nest01Dir}/noctalia.toml";
                };

              sprrw = {
                sops.opRef = "op://Private/nbui3ljmiwkx4aw2tvym6kkg4y";
              };
            };

          services.flatpak = {
            packages = [
              {
                appId = "org.musescore.MuseScore";
                origin = "flathub";
              }
              {
                appId = "org.prismlauncher.PrismLauncher";
                origin = "flathub";
              }
              {
                appId = "com.heroicgameslauncher.hgl";
                origin = "flathub";
              }
            ];

            overrides = {
              "org.musescore.MuseScore".Context = {
                sockets = [ "!cups" ];
              };
              "org.prismlauncher.PrismLauncher".Context = {
                filesystems = [
                  "!xdg-run/app/com.discordapp.Discord"
                  "!xdg-download"
                  "!~/.ftba"
                ];
              };
              "com.heroicgameslauncher.hgl".Context = {
                features = [ "!bluetooth" ];
                filesystems = [
                  "!/run/media"
                  "!~/.local/share/applications"
                  "!xdg-run/gamescope-0"
                  "!~/.local/share/lutris"
                  "!~/.steam/steam"
                  "!/mnt"
                  "!~/Games/Heroic"
                  "!xdg-documents"
                  "!/media"
                  "!~/.var/app/com.valvesoftware.Steam"
                  "!xdg-desktop"
                  "!xdg-config/MangoHud"
                  "!xdg-run/app/com.discordapp.Discord"
                  "!xdg-data/umu"
                  "!~/.steam"
                ];
              };
            };
          };

          nix.extraOptions = ''
            builders = ssh-ng://root@stacksparrow4 aarch64-linux /home/sprrw/.ssh/stacksparrow4
          '';

          boot.loader.efi.efiSysMountPoint = "/efi";
          boot.loader.systemd-boot.xbootldrMountPoint = "/boot";

          swapDevices = [
            {
              device = "/swapfile";
              size = 32 * 1024;
            }
          ];

          networking.hostName = "nest01";

          hardware.nvidia = {
            modesetting.enable = true;
            open = false;
            package = config.boot.kernelPackages.nvidiaPackages.stable;
          };
          services.xserver.videoDrivers = [ "nvidia" ];

          hardware.opentabletdriver.enable = true;

          system.stateVersion = "24.11";
        }
      )
    ];
  };
}
