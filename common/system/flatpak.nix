{ pkgs, config, lib, ... }:

{
  options.sprrw.flatpaks = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
        };

        extraCommands = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
    });
  };

  config = lib.mkIf (!config.sprrw.headless) {
    services.flatpak.enable = true;
    systemd.services.flatpak-sync = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '' + (lib.concatMapStrings ({name, extraCommands}: ''
        flatpak install -y flathub ${name}
        ${extraCommands}
      '') config.sprrw.flatpaks);
    };
  };
}
