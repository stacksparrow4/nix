{ config, moduleWithSystem, ... }:

{
  flake.homeModules.linux-sway = {
    # The bar/shell is part of the sway session, so it comes along with it.
    imports = [
      config.flake.homeModules.linux-noctalia

      (moduleWithSystem (
        { self', ... }:
        { pkgs, config, ... }:
        {
          home.file.".config/sway/config".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/linux/sway/config";
          home.file.".config/sway/alternating_layouts.py".source =
            "${self'.packages.alternating-layouts}/bin/alternating-layouts";

          services.kanshi.enable = true;

          home.pointerCursor = {
            gtk.enable = true;
            name = "Adwaita";
            package = pkgs.adwaita-icon-theme;
          };
        }
      ))
    ];
  };
}
