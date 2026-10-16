{
  flake.homeModules.cinny =
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
        defaultHomeserver = 0;
        homeserverList = [ "stacksparrow4.xyz" ];
        hashRouter = {
          enabled = true;
          basename = "/";
        };
      };

      cinny =
        pkgs.runCommand "cinny"
          {
            inherit (pkgs.cinny-unwrapped) version meta;
            nativeBuildInputs = [ pkgs.jq ];
            cinnyConf = builtins.toJSON cinnyConf;
            passAsFile = [ "cinnyConf" ];
          }
          ''
            cp -r ${pkgs.cinny-unwrapped} $out
            chmod -R u+w $out

            jq -s '.[0] * .[1]' \
              ${pkgs.cinny-unwrapped}/config.json "$cinnyConfPath" \
              > $out/config.json
          '';

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
