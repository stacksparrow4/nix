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
          appId = "com.usebruno.Bruno";
          origin = "flathub";
        }
        {
          appId = "com.valvesoftware.Steam";
          origin = "flathub";
        }
      ];

      overrides = {
        "dev.vencord.Vesktop".Context = {
          filesystems = [ "!~/.steam" ];
        };
        "com.valvesoftware.Steam".Context = {
          filesystems = [ "!xdg-config/MangoHud" "!xdg-music" "!xdg-pictures" "!xdg-run/app/com.discordapp.Discord" "!/run/media" "!/mnt" "!/media" ];
        };
      };
    };
  };
}
