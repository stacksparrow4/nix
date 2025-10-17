{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../common/home
  ];

  home = {
    username = "dan";
    homeDirectory = "/Users/dan";
  };

  sprrw = {
    nvim.enable = true;
    programming.enable = true;
    term = {
      enable = true;
      alacritty = {
        font = {
          family = "IosevkaTerm Nerd Font Mono";
          size = 14;
        };

        bindings = [
          { key = "Right"; mods = "Alt"; chars = "\\u001BF"; }
          { key = "Left";  mods = "Alt"; chars = "\\u001BB"; }
          { key = "Left";  mods = "Command"; chars = "\\u0001"; }
          { key = "Right"; mods = "Command"; chars = "\\u0005"; }
        ];

        installTerminfo = true;
      };
    };
  };

  # Fix for apps not showing up in spotlight search
  home.activation = {
    rsync-home-manager-applications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rsyncArgs="--archive --checksum --chmod=-w --copy-unsafe-links --delete"
      apps_source="$genProfilePath/home-path/Applications"
      moniker="Home Manager Trampolines"
      app_target_base="${config.home.homeDirectory}/Applications"
      app_target="$app_target_base/$moniker"
      mkdir -p "$app_target"
      ${pkgs.rsync}/bin/rsync $rsyncArgs "$apps_source/" "$app_target"
    '';
  };
}
