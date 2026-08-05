{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    {
      packages = {
        vimgolf = pkgs.writeShellScriptBin "vimgolf" ''
          export PATH="${pkgs.vim}/bin:$PATH"
          ${pkgs.vimgolf}/bin/vimgolf "$@"
        '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
