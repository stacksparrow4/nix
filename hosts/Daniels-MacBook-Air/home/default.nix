{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../common/home
  ];

  home = {
    username = "dan";
    homeDirectory = "/Users/dan";
  };

  sprrw.useAllEnvironments = false;
  
  sprrw.macosMode = true;
  sprrw.rofi.enable = false;

  sprrw.packages = {
    installGuiPackages = false;
    installLinuxPackages = false;
  };

  sprrw.zshrc.enable = true;

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
