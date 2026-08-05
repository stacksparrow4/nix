{
  pkgs,
  config,
  lib,
  self',
  ...
}:

{
  imports = [ ./noctalia ];

  options = {
    sprrw.linux.sway.enable = lib.mkEnableOption "sway";
  };

  config = lib.mkIf config.sprrw.linux.sway.enable {
    home.file.".config/sway/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/linux/sway/config";
    home.file.".config/sway/alternating_layouts.py".source =
      "${self'.packages.alternating-layouts}/bin/alternating-layouts";

    services.kanshi = {
      enable = true;
    };

    home.pointerCursor = {
      gtk.enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
}
