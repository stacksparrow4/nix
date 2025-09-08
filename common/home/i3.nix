{ pkgs, config, lib, ... }:

{
  home.file = lib.mkIf (!config.sprrw.macosMode) {
    ".config/i3/config".text = builtins.readFile ./dotfiles/i3/config;
    ".config/i3status/config".source = ./dotfiles/i3status/config;
    ".config/i3/alternating_layouts.py".source = let
      alternatingLayoutsDeriv = pkgs.stdenv.mkDerivation {
        name = "alternating-layouts";
        propagatedBuildInputs = [
          pkgs.pywithi3ipc
          # (pkgs.python313.withPackages (ppkgs: [
          #                               ppkgs.i3ipc
          # ]))
        ];
        dontUnpack = true;
        installPhase = "install -Dm755 ${./dotfiles/i3/alternating_layouts.py} $out/bin/alternating-layouts";
      }; in
    "${alternatingLayoutsDeriv}/bin/alternating-layouts";
  };
}
