{ pkgs, config, lib, ... }:

{
  options = {
    sprrw.linux.i3.enable = lib.mkEnableOption "i3";
  };

  config = lib.mkIf config.sprrw.linux.i3.enable {
    home.file = {
      ".config/i3/config".text = builtins.readFile ./i3/config;
      ".config/i3/alternating_layouts.py".source = let
        alternatingLayoutsDeriv = pkgs.stdenv.mkDerivation {
          name = "alternating-layouts";
          propagatedBuildInputs = [
            (pkgs.python313.withPackages (ppkgs: [
                                          ppkgs.i3ipc
            ]))
          ];
          dontUnpack = true;
          installPhase = "install -Dm755 ${./i3/alternating_layouts.py} $out/bin/alternating-layouts";
        }; in
      "${alternatingLayoutsDeriv}/bin/alternating-layouts";
    };

    programs.waybar = {
      enable = true;
    };
    home.file.".config/waybar/config.jsonc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/linux/waybar.jsonc";
  };
}
