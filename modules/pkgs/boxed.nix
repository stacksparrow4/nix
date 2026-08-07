{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        bx = mkSandbox {
          name = "bx";
          sharedPaths = [
            {
              hostPath = "$HOME/.config/brave-search";
              boxPath = "/home/sprrw/.config/brave-search";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${pkgs.brave-search-cli}/bin/bx";
        };

        nodemon = mkSandbox {
          name = "nodemon";
          shareCwd = true;
          network = true;
          prog = "${pkgs.nodemon}/bin/nodemon";
        };

        dumbpipe = mkSandbox {
          name = "dumbpipe";
          network = true;
          prog = "${pkgs.dumbpipe}/bin/dumbpipe";
        };

        wlfreerdp = mkSandbox {
          name = "wlfreerdp";
          wayland = true;
          network = true;
          prog = "${pkgs.freerdp}/bin/wlfreerdp";
        };

        sage = mkSandbox {
          name = "sage";
          shareCwd = true;
          prog = "${pkgs.sage}/bin/sage";
        };

        neofetch = mkSandbox {
          name = "neofetch";
          prog = "${pkgs.fastfetch}/bin/fastfetch";
        };

        shtris = mkSandbox {
          name = "shtris";
          prog = "${pkgs.shtris}/bin/shtris";
        };

        zbarimg = mkSandbox {
          name = "zbarimg";
          prog = "${pkgs.zbar}/bin/zbarimg";
        };

        twitch-dl = mkSandbox {
          name = "twitch-dl";
          shareCwd = true;
          network = true;
          prog = "${pkgs.twitch-dl}/bin/twitch-dl";
        };

        yt-dlp = mkSandbox {
          name = "yt-dlp";
          shareCwd = true;
          network = true;
          prog = "${pkgs.yt-dlp}/bin/yt-dlp";
        };
      };
    };
}
