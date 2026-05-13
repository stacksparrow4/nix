{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./obs.nix
    ./browsers.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui = {
      browsers.enable = true;
      obs.enable = true;
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
      (config.sprrw.sandbox.create {
        name = "grim";
        wayland = true;
        prog = "${pkgs.grim}/bin/grim";
      })
      (config.sprrw.sandbox.create {
        name = "slurp";
        wayland = true;
        prog = "${pkgs.slurp}/bin/slurp";
      })
      (config.sprrw.sandbox.create {
        name = "swappy";
        stdin = true;
        wayland = true;
        prog = "${pkgs.swappy}/bin/swappy";
      })
    ];
  };
}
