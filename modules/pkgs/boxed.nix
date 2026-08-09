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

        exiftool = mkSandbox {
          name = "exiftool";
          prog = "${pkgs.exiftool}/bin/exiftool";
          shareCwd = true;
        };

        binwalk = mkSandbox {
          name = "binwalk";
          prog = "${pkgs.binwalk}/bin/binwalk";
          shareCwd = true;
        };

        ent = mkSandbox {
          name = "ent";
          prog = "${pkgs.ent}/bin/ent";
          shareCwd = true;
        };

        apktool = mkSandbox {
          name = "apktool";
          shareCwd = true;
          prog = "${pkgs.apktool}/bin/apktool";
        };

        jadx = mkSandbox {
          name = "jadx";
          shareCwd = true;
          prog = "${pkgs.jadx}/bin/jadx";
        };

        hydra = mkSandbox {
          name = "hydra";
          shareCwd = true;
          network = true;
          prog = "${pkgs.thc-hydra}/bin/hydra";
        };

        pwninit = mkSandbox {
          name = "pwninit";
          shareCwd = true;
          prog = "${pkgs.pwninit}/bin/pwninit";
        };

        ropr = mkSandbox {
          name = "ropr";
          shareCwd = true;
          prog = "${pkgs.ropr}/bin/ropr";
        };

        ROPgadget = mkSandbox {
          name = "ROPgadget";
          shareCwd = true;
          prog = "${pkgs.ropgadget}/bin/ROPgadget";
        };

        snmpwalk = mkSandbox {
          name = "snmpwalk";
          network = true;
          prog = "${pkgs.net-snmp}/bin/snmpwalk";
        };

        snmpcheck = mkSandbox {
          name = "snmpcheck";
          network = true;
          prog = "${pkgs.snmpcheck}/bin/snmpcheck";
        };

        evil-winrm = mkSandbox {
          name = "evil-winrm";
          prog = "${pkgs.evil-winrm}/bin/evil-winrm";
          network = true;
        };

        certipy = mkSandbox {
          name = "certipy";
          prog = "${pkgs.certipy}/bin/certipy";
          shareCwd = true;
          network = true;
        };

        bloodyAD = mkSandbox {
          name = "bloodyAD";
          prog = "${pkgs.python312Packages.bloodyad}/bloodyAD";
          shareCwd = true;
          network = true;
        };

        pwsh = mkSandbox {
          name = "pwsh";
          prog = "${pkgs.powershell}/bin/pwsh";
          network = true;
        };

        nuclei =
          let
            nucleiTemplates = pkgs.fetchFromGitHub {
              owner = "projectdiscovery";
              repo = "nuclei-templates";
              rev = "ee71c007b30bf63a44f500ffeebf11741324f7e2";
              hash = "sha256-MNx/RcGyvspH6qECuNqQ3mBYtsBMvH/w36IDbUAkyiA=";
            };
          in
          mkSandbox {
            name = "nuclei";
            sharedPaths = [
              {
                hostPath = "${nucleiTemplates}";
                boxPath = "/home/sprrw/.local/nuclei-templates";
                ro = true;
                type = "dir";
              }
              {
                hostPath = "$HOME/.config/nuclei";
                boxPath = "/home/sprrw/.config/nuclei";
                ro = false;
                type = "dir";
              }
            ];
            shareCwd = true;
            network = true;
            prog = "${pkgs.nuclei}/bin/nuclei -ud /home/sprrw/.local/nuclei-templates -duc";
          };

        sqlmap = mkSandbox {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${pkgs.sqlmap}/bin/sqlmap";
        };

        feroxbuster = mkSandbox {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${pkgs.feroxbuster}/bin/feroxbuster";
        };

        ffuf = mkSandbox {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${pkgs.ffuf}/bin/ffuf";
        };

        shortscan = mkSandbox {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${pkgs.shortscan}/bin/shortscan";
        };

        gau = mkSandbox {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${pkgs.gau}/bin/gau";
        };

        naabu = mkSandbox {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${pkgs.naabu}/bin/naabu";
        };

        clairvoyance = mkSandbox {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${pkgs.clairvoyance}/bin/clairvoyance";
        };

        sourcemapper = mkSandbox {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${pkgs.sourcemapper}/bin/sourcemapper";
        };

        subfinder = mkSandbox {
          name = "subfinder";
          shareCwd = true;
          network = true;
          prog = "${pkgs.subfinder}/bin/subfinder";
        };

        mitmproxy = mkSandbox {
          name = "mitmproxy";
          prog = "${pkgs.mitmproxy}/bin/mitmproxy";
          shareCwd = true;
          sharedPaths = [
            {
              hostPath = "$HOME/.mitmproxy";
              boxPath = "/home/sprrw/.mitmproxy";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
        };

        ilspycmd = mkSandbox {
          name = "ilspycmd";
          shareCwd = true;
          prog = "${pkgs.ilspycmd}/bin/ilspycmd";
        };
      };
    };
}
