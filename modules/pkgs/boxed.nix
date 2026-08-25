{
  perSystem =
    {
      pkgsLinux,
      mkSandbox,
      ...
    }:
    {
      packages = {
        bx = mkSandbox {
          name = "bx";
          sharedPaths = [
            {
              hostPath = "$HOME/.config/brave-search";
              boxPath = "~/.config/brave-search";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${pkgsLinux.brave-search-cli}/bin/bx";
        };

        nodemon = mkSandbox {
          name = "nodemon";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.nodemon}/bin/nodemon";
        };

        dumbpipe = mkSandbox {
          name = "dumbpipe";
          network = true;
          prog = "${pkgsLinux.dumbpipe}/bin/dumbpipe";
        };

        wlfreerdp = mkSandbox {
          name = "wlfreerdp";
          wayland = true;
          network = true;
          prog = "${pkgsLinux.freerdp}/bin/wlfreerdp";
        };

        sage = mkSandbox {
          name = "sage";
          shareCwd = true;
          prog = "${pkgsLinux.sage}/bin/sage";
        };

        neofetch = mkSandbox {
          name = "neofetch";
          prog = "${pkgsLinux.fastfetch}/bin/fastfetch";
        };

        shtris = mkSandbox {
          name = "shtris";
          prog = "${pkgsLinux.shtris}/bin/shtris";
        };

        zbarimg = mkSandbox {
          name = "zbarimg";
          prog = "${pkgsLinux.zbar}/bin/zbarimg";
        };

        twitch-dl = mkSandbox {
          name = "twitch-dl";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.twitch-dl}/bin/twitch-dl";
        };

        yt-dlp = mkSandbox {
          name = "yt-dlp";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.yt-dlp}/bin/yt-dlp";
        };

        exiftool = mkSandbox {
          name = "exiftool";
          prog = "${pkgsLinux.exiftool}/bin/exiftool";
          shareCwd = true;
        };

        binwalk = mkSandbox {
          name = "binwalk";
          prog = "${pkgsLinux.binwalk}/bin/binwalk";
          shareCwd = true;
        };

        ent = mkSandbox {
          name = "ent";
          prog = "${pkgsLinux.ent}/bin/ent";
          shareCwd = true;
        };

        apktool = mkSandbox {
          name = "apktool";
          shareCwd = true;
          prog = "${pkgsLinux.apktool}/bin/apktool";
        };

        jadx = mkSandbox {
          name = "jadx";
          shareCwd = true;
          prog = "${pkgsLinux.jadx}/bin/jadx";
        };

        hydra = mkSandbox {
          name = "hydra";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.thc-hydra}/bin/hydra";
        };

        pwninit = mkSandbox {
          name = "pwninit";
          shareCwd = true;
          prog = "${pkgsLinux.pwninit}/bin/pwninit";
        };

        ropr = mkSandbox {
          name = "ropr";
          shareCwd = true;
          prog = "${pkgsLinux.ropr}/bin/ropr";
        };

        ROPgadget = mkSandbox {
          name = "ROPgadget";
          shareCwd = true;
          prog = "${pkgsLinux.ropgadget}/bin/ROPgadget";
        };

        snmpwalk = mkSandbox {
          name = "snmpwalk";
          network = true;
          prog = "${pkgsLinux.net-snmp}/bin/snmpwalk";
        };

        snmpcheck = mkSandbox {
          name = "snmpcheck";
          network = true;
          prog = "${pkgsLinux.snmpcheck}/bin/snmpcheck";
        };

        evil-winrm = mkSandbox {
          name = "evil-winrm";
          prog = "${pkgsLinux.evil-winrm}/bin/evil-winrm";
          network = true;
        };

        certipy = mkSandbox {
          name = "certipy";
          prog = "${pkgsLinux.certipy}/bin/certipy";
          shareCwd = true;
          network = true;
        };

        bloodyAD = mkSandbox {
          name = "bloodyAD";
          prog = "${pkgsLinux.python312Packages.bloodyad}/bloodyAD";
          shareCwd = true;
          network = true;
        };

        pwsh = mkSandbox {
          name = "pwsh";
          prog = "${pkgsLinux.powershell}/bin/pwsh";
          network = true;
        };

        nuclei =
          let
            nucleiTemplates = pkgsLinux.fetchFromGitHub {
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
                boxPath = "~/.local/nuclei-templates";
                ro = true;
                type = "dir";
              }
              {
                hostPath = "$HOME/.config/nuclei";
                boxPath = "~/.config/nuclei";
                ro = false;
                type = "dir";
              }
            ];
            shareCwd = true;
            network = true;
            prog = "${pkgsLinux.nuclei}/bin/nuclei -ud /home/sprrw/.local/nuclei-templates -duc";
          };

        sqlmap = mkSandbox {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.sqlmap}/bin/sqlmap";
        };

        feroxbuster = mkSandbox {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.feroxbuster}/bin/feroxbuster";
        };

        ffuf = mkSandbox {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.ffuf}/bin/ffuf";
        };

        shortscan = mkSandbox {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.shortscan}/bin/shortscan";
        };

        gau = mkSandbox {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.gau}/bin/gau";
        };

        naabu = mkSandbox {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.naabu}/bin/naabu";
        };

        clairvoyance = mkSandbox {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.clairvoyance}/bin/clairvoyance";
        };

        sourcemapper = mkSandbox {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.sourcemapper}/bin/sourcemapper";
        };

        subfinder = mkSandbox {
          name = "subfinder";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.subfinder}/bin/subfinder";
        };

        mitmproxy = mkSandbox {
          name = "mitmproxy";
          prog = "${pkgsLinux.mitmproxy}/bin/mitmproxy";
          shareCwd = true;
          sharedPaths = [
            {
              hostPath = "$HOME/.mitmproxy";
              boxPath = "~/.mitmproxy";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
        };

        ilspycmd = mkSandbox {
          name = "ilspycmd";
          shareCwd = true;
          prog = "${pkgsLinux.ilspycmd}/bin/ilspycmd";
        };
      };
    };
}
