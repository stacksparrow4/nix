{ inputs, ... }:

{
  flake.nixosModules.flatpak = {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    config = {
      services.flatpak.enable = true;
    };
  };

  flake.nixosModules.apps = {
    services.flatpak = {
      packages = [
        {
          appId = "dev.vencord.Vesktop";
          origin = "flathub";
        }
        {
          appId = "org.libreoffice.LibreOffice";
          origin = "flathub";
        }
        {
          appId = "com.valvesoftware.Steam";
          origin = "flathub";
        }
        {
          appId = "com.spotify.Client";
          origin = "flathub";
        }
        {
          appId = "io.github.seadve.Kooha";
          origin = "flathub";
        }
      ];

      overrides = {
        "dev.vencord.Vesktop".Context = {
          shared = [ "!ipc" ];
          sockets = [ "!fallback-x11" ];
          filesystems = [ "!~/.steam" ];
        };
        "org.libreoffice.LibreOffice".Context = {
          shared = [ "!ipc" ];
          sockets = [ "!fallback-x11" "!cups" ];
        };
        "com.valvesoftware.Steam".Context = {
          filesystems = [ "!xdg-config/MangoHud" "!xdg-music" "!xdg-pictures" "!xdg-run/app/com.discordapp.Discord" "!/run/media" "!/mnt" "!/media" ];
        };
        "com.spotify.Client".Context = {
          shared = [ "!ipc" ];
          filesystems = [ "!xdg-pictures" "!xdg-music"];
        };
        "io.github.seadve.Kooha".Context = {
          shared = [ "!ipc" ];
          sockets = [ "!x11" "!fallback-x11" ];
        };
      };
    };
  };
}
