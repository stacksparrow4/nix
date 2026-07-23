{
  pkgs,
  config,
  lib,
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
      let
        alternatingLayoutsDeriv = pkgs.stdenv.mkDerivation {
          name = "alternating-layouts";
          propagatedBuildInputs = [
            (pkgs.python313.withPackages (ppkgs: [
              ppkgs.i3ipc
            ]))
          ];
          dontUnpack = true;
          installPhase = "install -Dm755 ${./sway/alternating_layouts.py} $out/bin/alternating-layouts";
        };
      in
      "${alternatingLayoutsDeriv}/bin/alternating-layouts";

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
