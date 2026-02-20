{ pkgs, config, lib, ... }:

{
  options = {
    sprrw.linux.i3.enable = lib.mkEnableOption "i3";
  };

  config = lib.mkIf config.sprrw.linux.i3.enable {
    home.file = {
      ".config/i3/config".text = builtins.readFile ./i3/config;
      ".config/i3blocks/config".source = ./i3blocks/config;
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
      settings.main = {
        modules-left = ["sway/workspaces"];
        modules-center = [
          "clock" 
          "network" 
          "pulseaudio"
        ];
        modules-right = [
          "tray"
          "battery"
        ];
        clock = {
        format = "{:%H:%M %d-%m-%y}";
          tooltip = false;
        };
        tray = {
          spacing = 10;
        };
        network = {
          format = "{ifname}";
          format-alt = "{ipaddr}";
          format-wifi = "{essid} ({signalStrength}%)";
          tooltip = false;
          max-length = 50;
        };
      };
    };
  };
}
