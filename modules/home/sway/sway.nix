{ config, moduleWithSystem, ... }:

{
  flake.modules.homeManager.sway = {
    # The bar/shell is part of the sway session, so it comes along with it.
    imports = [
      config.flake.modules.homeManager.noctalia

      (moduleWithSystem (
        { self', ... }:
        { pkgs, config, ... }:
        {
          home.file.".config/sway/config".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/sway/config";
          home.file.".config/sway/conf.d/alternating-layouts".text =
            "exec --no-startup-id ${self'.packages.alternating-layouts}/bin/alternating-layouts";

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
