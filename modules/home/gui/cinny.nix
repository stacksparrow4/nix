{
  flake.homeModules.gui-cinny =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      host = "127.0.0.1";
      port = 8787;
      url = "http://${host}:${toString port}";

      cinnyConf = {
        # defaultHomeserver = 0;
        # homeserverList = [ "stacksparrow4.xyz" ];
      };

      elementCall = pkgs.fetchzip {
        url = "https://registry.npmjs.org/@element-hq/element-call-embedded/-/element-call-embedded-0.26.1.tgz";
        hash = "sha256-AMGSDVR/+hAG2QDODRrRwoDOu2QuxYtGZe1c0zkC5V0=";
      };

      elementCallConf = {
        media_quality = {
          # video_codec = "vp9"; # LiveKit server must allow it
          screen_share = {
            max_resolution = 1440; # height in px (EC default 1080)
            max_framerate = 60; # EC default 30
            max_bitrate = 8000000; # bps (EC default 5 Mbps)
          };
        };
      };

      cinny-unwrapped =
        pkgs.runCommand "cinny-unwrapped-ec"
          {
            inherit (pkgs.cinny-unwrapped) version meta;
            nativeBuildInputs = [ pkgs.jq ];
            elementCallConf = builtins.toJSON elementCallConf;
            passAsFile = [ "elementCallConf" ];
          }
          ''
            cp -r ${pkgs.cinny-unwrapped} $out
            chmod -R u+w $out

            rm -rf $out/public/element-call
            cp -r ${elementCall}/dist $out/public/element-call
            chmod -R u+w $out/public/element-call

            jq -s '.[0] * .[1]' \
              ${elementCall}/dist/config.json "$elementCallConfPath" \
              > $out/public/element-call/config.json
          '';

      cinny = pkgs.cinny.override {
        inherit cinny-unwrapped;
        conf = cinnyConf;
      };

      launcher = pkgs.writeShellScriptBin "cinny" ''
        exec ${lib.getExe pkgs.chromium} \
          --app=${url} \
          --user-data-dir="${config.xdg.dataHome}/cinny-chromium" \
          --class=cinny \
          "$@"
      '';
    in
    {
      home.packages = [ launcher ];

      systemd.user.services.cinny-web = {
        Unit.Description = "Cinny web client (local static server)";
        Service = {
          ExecStart = lib.escapeShellArgs [
            (lib.getExe pkgs.static-web-server)
            "--host"
            host
            "--port"
            (toString port)
            "--root"
            "${cinny}"
            "--page-fallback"
            "${cinny}/index.html"
            "--log-level"
            "error"
          ];
          Restart = "on-failure";
        };
        Install.WantedBy = [ "default.target" ];
      };

      xdg.desktopEntries.cinny = {
        name = "Cinny";
        genericName = "Matrix Client";
        comment = "Yet another Matrix client";
        exec = "${lib.getExe launcher}";
        icon = "${cinny}/public/android/android-chrome-512x512.png";
        terminal = false;
        categories = [
          "Network"
          "InstantMessaging"
          "Chat"
        ];
      };
    };
}
