{
  pkgs,
  lib,
  config,
  mkSandbox,
  ...
}:

{
  imports = [
    ./obs.nix
    ./browsers.nix
    ./emoji-picker.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui = {
      browsers.enable = true;
      obs.enable = true;
      emoji-picker.enable = true;
    };

    home.packages = with pkgs; [
      gimp
      inkscape
      spotify
      krita
      kdePackages.kdenlive
      vlc
      blender
      rofi
      freerdp
      feh
      xfce.thunar
      (mkSandbox {
        name = "grim";
        wayland = true;
        prog = "${pkgs.grim}/bin/grim";
      })
      (mkSandbox {
        name = "slurp";
        wayland = true;
        prog = "${pkgs.slurp}/bin/slurp";
      })
      (mkSandbox {
        name = "swappy";
        stdin = true;
        wayland = true;
        prog = "${pkgs.swappy}/bin/swappy";
      })
    ];
  };
}
