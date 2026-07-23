{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf config.sprrw.linux.sway.enable {
    programs.noctalia = {
      enable = true;

      settings = {
        bar.default = {
          center = [ "control-center" "clock" ];
          end = [ "media" "spacer_1" "tray" "notifications" "group:g1" "group:g2" "session" ];
          font_family = "IosevkaTerm NF";
          margin_ends = 0;
          radius = 0;
          start = [ "workspaces" ];

          capsule_group = [
            {
              enabled = true;
              fill = "surface_variant";
              id = "g1";
              members = [ "cpu" "ram" ];
              opacity = 1.0;
              padding = 6.0;
            }
            {
              enabled = true;
              fill = "surface_variant";
              id = "g2";
              members = [ "network" "bluetooth" "volume" "brightness" "battery" ];
              opacity = 1.0;
              padding = 6.0;
            }
          ];
        };

        widget.spacer_1 = {
          type = "spacer";
        };

        desktop_widgets.enabled = false;

        shell = {
          clipboard_enabled = false;
          font_family = "IosevkaTerm NF";
          popup_shadows = false;
          time_format = "{:%-I:%M %p}";

          animation.enabled = false;

          screenshot.save_to_file = false;

          shadow.alpha = 0.0;
        };

        theme = {
          builtin = "Rosé Pine";
          community_palette = "Oxocarbon";
          mode = "dark";
          source = "builtin";
          wallpaper_scheme = "m3-content";
        };

        wallpaper.enabled = false;

        weather.enabled = false;

        widget.workspaces.scale = 1.2;

        widget.clock.format = "{:%-I:%M %p}";
      };
    };
  };
}
