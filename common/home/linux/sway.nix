{ pkgs, config, lib, ... }:

{
  options = {
    sprrw.linux.sway.enable = lib.mkEnableOption "sway";
  };

  config = lib.mkIf config.sprrw.linux.sway.enable {
    home.file.".config/sway/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/linux/sway/config";
    home.file.".config/sway/alternating_layouts.py".source = let
      alternatingLayoutsDeriv = pkgs.stdenv.mkDerivation {
        name = "alternating-layouts";
        propagatedBuildInputs = [
          (pkgs.python313.withPackages (ppkgs: [
                                        ppkgs.i3ipc
          ]))
        ];
        dontUnpack = true;
        installPhase = "install -Dm755 ${./sway/alternating_layouts.py} $out/bin/alternating-layouts";
      }; in
    "${alternatingLayoutsDeriv}/bin/alternating-layouts";

    programs.waybar = {
      enable = true;
    };
    home.file.".config/waybar/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/linux/waybar/waybar.jsonc";
    home.file.".config/waybar/style.css".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/linux/waybar/style.css";

    services.mako = {
      enable = true;
      settings = {
        default-timeout = 10000;
      };
    };
  };
}
