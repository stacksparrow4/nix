{ pkgs, lib, config, ... }:

{
  options.sprrw.sec.burp = {
    enable = lib.mkEnableOption "burp";

    pro = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = let
    cfg = config.sprrw.sec.burp;
  in lib.mkIf cfg.enable {
    home.packages = [(
      let
        proEdition = cfg.pro;
        communityIconB64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAApVBMVEUAorkNprwcrMB7ztr///+V2OFLvc39/v4nsMPx+ftFu8sPp73Y8PR6ztoCorm15Oqq4OeH097R7vILprxXwdDs+PkgrcEws8b1+/z7/f1BucoUqb7g8/ZuytcEo7rA6O2f2+SU1+H5/P2C0dw7t8ljxtQ5tsgbq8Dn9vgIpLvK6/Axs8Z2zdm55ev4/P2c2uNsydZAucrr9/kKpbvQ7fKp3+fw+fqszG+qAAAA20lEQVR4Ae3WNVoFQRRE4Xr0fe7u7jI47H9pTEVDhNTlI+o/r5OMdCOKvpW7S+WgC5YKrkAM5J2BQtEXKJW5L1YgqtaM6hA1mkYtqNpGnS5EPaP+AKLhiPvxBKLpzGgO0WJptIJqbbTZBtrh1/aWUd7Ew8YXOJ7MFThfzBe43jJJ/KX9USC5Za5K4JPL2Rc4HeEKbA7wBfb4tV2g7b3RGqoHo+UCokej2RSipzH3oyFEg2ejHkQvr0ZtqN6Mmg2I6ka1KkSVIvfvJd/XWCzAF1jHX9o/BPzX/Sj6AIysEdcamV/YAAAAAElFTkSuQmCC";
        proIconB64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAnFBMVEVbT/9jV/9tYv+qo/////+6tf+Lgv/9/f90af/19f+Hfv9kWf/l5P+po/9cUP/Py//IxP+xrP/h3/9iVv+Si//y8f9vZf95cP/4+P/8/P+Ee/9nXP/r6f+hmv9dUf/W0//BvP/7+v+uqP+Ad/+ak/9/dv9sYf/v7v9gVP/c2v96cP+moP/Rzv/6+v+/uv+gmf9hVf/g3v/Hw//19P8g0/xMAAAA2klEQVR4Ae3WNXrFMBRE4XnRfczMzLbD+99bPJVTBebmS6W/n9MYJETRt0oPuRJ0wXLBFYiBsjNQqfoCtTr31QZEzZZRG6JO16gHVd9oMIRoZDSeQDSdcT9fQLRcGa0h2myNdr430PaHQEf82skKypt43vsCl6u5Are7+QJJWsjiL+2PAllaSJTAJ/ebL3C9wBXYn+ELnPBrx0CHR6MyVE9G2w1Ez0arJUSLOfezKUSTsdEIopdXoz5Ub0bdDkRto1YTokaV+/ea72usVuALlOMv7R8D+nU/ij4AkKERE6vBiJsAAAAASUVORK5CYII=";
        iconB64 = if proEdition then proIconB64 else communityIconB64;
        patchedBurp = pkgs.buildFHSEnv {
          name = "burpsuite";

          runScript = "${pkgs.jdk}/bin/java -jar ~/.local/share/burpdownload/burp.jar";

          targetPkgs =
            pkgs: with pkgs; [
              alsa-lib
              at-spi2-core
              cairo
              cups
              dbus
              expat
              glib
              gtk3
              gtk3-x11
              jython
              libcanberra-gtk3
              libdrm
              udev
              libxkbcommon
              libgbm
              nspr
              nss
              pango
              xorg.libX11
              xorg.libxcb
              xorg.libXcomposite
              xorg.libXdamage
              xorg.libXext
              xorg.libXfixes
              xorg.libXrandr
            ];
        };
        shellWrapper = pkgs.writeShellApplication {
          name = "burpsuite-wrapper";
          runtimeInputs = with pkgs; [curl jq coreutils];
          text = ''
            jsondata=$(
              curl -s 'https://portswigger.net/burp/releases/data' |
              jq -r '
                [
                  .ResultSet.Results[]
                  | select(
                      (.categories | sort) == (["Professional","Community"] | sort)
                      and .releaseChannels == ["Early Adopter"]
                    )
                ][0].builds[]
                | select(.ProductPlatform == "Jar")
                | select (.ProductId=="${if proEdition then "pro" else "community"}")')

            productName=$(echo "$jsondata" | jq -r ".ProductId")
            version=$(echo "$jsondata" | jq -r ".Version")
            shasum=$(echo "$jsondata" | jq -r ".Sha256Checksum")

            mkdir -p ~/.local/share/burpdownload

            if ! [[ -f ~/.local/share/burpdownload/version.txt ]]; then
              echo 0 > ~/.local/share/burpdownload/version.txt
            fi

            oldversion=$(cat ~/.local/share/burpdownload/version.txt)
            if [[ "$oldversion" != "$version" ]]; then
              echo "Updating version from $oldversion to $version"
              curl -o ~/.local/share/burpdownload/burp.jar "https://portswigger.net/burp/releases/download?product=$productName&version=$version&type=Jar"
              echo "$version" > ~/.local/share/burpdownload/version.txt
            fi

            if [[ "$(sha256sum ~/.local/share/burpdownload/burp.jar | cut -d' ' -f1)" != "$shasum" ]]; then
              echo "Error: sha256sum for burp install did not match"
              exit 1
            fi

            ${patchedBurp}/bin/burpsuite
          '';
        };
        desktopItem = pkgs.makeDesktopItem {
          name = "burpsuite";
          exec = "burpsuite";
          icon = "burpsuite";
          desktopName = if proEdition then "Burp Suite Professional Edition" else "Burp Suite Community Edition";
          comment = "Integrated platform for performing security testing of web applications";
          categories = [
            "Development"
            "Security"
            "System"
          ];
        };
      in pkgs.runCommand "burpsuite-deriv" {} ''
        mkdir -p "$out/share/pixmaps"
        echo "${iconB64}" | base64 -d > "$out/share/pixmaps/burpsuite.png"
        cp -r ${desktopItem}/share/applications $out/share
        mkdir -p "$out/bin"
        ln -s "${shellWrapper}/bin/burpsuite-wrapper" "$out/bin/burpsuite"
      ''
    )];
  };
}
