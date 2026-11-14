{ inputs, ... }:

{
  flake.modules.nixos.flatpak = {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    config = {
      services.flatpak.enable = true;
    };
  };

  flake.modules.nixos.apps = {
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
          appId = "io.github.seadve.Kooha";
          origin = "flathub";
        }
        {
          appId = "moe.sable.client";
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
          sockets = [
            "!fallback-x11"
            "!cups"
          ];
        };
        "io.github.seadve.Kooha".Context = {
          shared = [ "!ipc" ];
          sockets = [
            "!x11"
            "!fallback-x11"
          ];
        };
      };
    };
  };
}
