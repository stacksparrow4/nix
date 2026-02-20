{ pkgs, lib, config, ... }:

{
  options.sprrw.gui.flameshot = {
    enable = lib.mkEnableOption "flameshot";
  };

  config = let
    cfg = config.sprrw.gui.flameshot;
  in lib.mkIf cfg.enable {
    services.flameshot = {
      enable = true;
      package = pkgs.writeShellApplication {
        name = "flameshot";
        text = ''
          QT_QPA_PLATFORM=xcb ${pkgs.flameshot}/bin/flameshot gui --raw | wl-copy
        '';
      };
      settings = {
        General = {
          showStartupLaunchMessage = false;
          disabledTrayIcon = true;
          showDesktopNotification = false;
          showAbortNotification = false;
          showHelp = false;
        };
      };
    };
  };
}
