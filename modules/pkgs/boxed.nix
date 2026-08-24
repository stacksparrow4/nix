{
  perSystem =
    {
      pkgs-linux,
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
          prog = "${pkgs-linux.brave-search-cli}/bin/bx";
        };

        nodemon = mkSandbox {
          name = "nodemon";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.nodemon}/bin/nodemon";
        };

        dumbpipe = mkSandbox {
          name = "dumbpipe";
          network = true;
          prog = "${pkgs-linux.dumbpipe}/bin/dumbpipe";
        };

        wlfreerdp = mkSandbox {
          name = "wlfreerdp";
          wayland = true;
          network = true;
          prog = "${pkgs-linux.freerdp}/bin/wlfreerdp";
        };

        sage = mkSandbox {
          name = "sage";
          shareCwd = true;
          prog = "${pkgs-linux.sage}/bin/sage";
        };

        neofetch = mkSandbox {
          name = "neofetch";
          prog = "${pkgs-linux.fastfetch}/bin/fastfetch";
        };

        shtris = mkSandbox {
          name = "shtris";
          prog = "${pkgs-linux.shtris}/bin/shtris";
        };

        zbarimg = mkSandbox {
          name = "zbarimg";
          prog = "${pkgs-linux.zbar}/bin/zbarimg";
        };

        twitch-dl = mkSandbox {
          name = "twitch-dl";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.twitch-dl}/bin/twitch-dl";
        };

        yt-dlp = mkSandbox {
          name = "yt-dlp";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.yt-dlp}/bin/yt-dlp";
        };

        exiftool = mkSandbox {
          name = "exiftool";
          prog = "${pkgs-linux.exiftool}/bin/exiftool";
          shareCwd = true;
        };

        binwalk = mkSandbox {
          name = "binwalk";
          prog = "${pkgs-linux.binwalk}/bin/binwalk";
          shareCwd = true;
        };

        ent = mkSandbox {
          name = "ent";
          prog = "${pkgs-linux.ent}/bin/ent";
          shareCwd = true;
        };

        apktool = mkSandbox {
          name = "apktool";
          shareCwd = true;
          prog = "${pkgs-linux.apktool}/bin/apktool";
        };

        jadx = mkSandbox {
          name = "jadx";
          shareCwd = true;
          prog = "${pkgs-linux.jadx}/bin/jadx";
        };

        hydra = mkSandbox {
          name = "hydra";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.thc-hydra}/bin/hydra";
        };

        pwninit = mkSandbox {
          name = "pwninit";
          shareCwd = true;
          prog = "${pkgs-linux.pwninit}/bin/pwninit";
        };

        ropr = mkSandbox {
          name = "ropr";
          shareCwd = true;
          prog = "${pkgs-linux.ropr}/bin/ropr";
        };

        ROPgadget = mkSandbox {
          name = "ROPgadget";
          shareCwd = true;
          prog = "${pkgs-linux.ropgadget}/bin/ROPgadget";
        };

        snmpwalk = mkSandbox {
          name = "snmpwalk";
          network = true;
          prog = "${pkgs-linux.net-snmp}/bin/snmpwalk";
        };

        snmpcheck = mkSandbox {
          name = "snmpcheck";
          network = true;
          prog = "${pkgs-linux.snmpcheck}/bin/snmpcheck";
        };

        evil-winrm = mkSandbox {
          name = "evil-winrm";
          prog = "${pkgs-linux.evil-winrm}/bin/evil-winrm";
          network = true;
        };

        certipy = mkSandbox {
          name = "certipy";
          prog = "${pkgs-linux.certipy}/bin/certipy";
          shareCwd = true;
          network = true;
        };

        bloodyAD = mkSandbox {
          name = "bloodyAD";
          prog = "${pkgs-linux.python312Packages.bloodyad}/bloodyAD";
          shareCwd = true;
          network = true;
        };

        pwsh = mkSandbox {
          name = "pwsh";
          prog = "${pkgs-linux.powershell}/bin/pwsh";
          network = true;
        };

        nuclei =
          let
            nucleiTemplates = pkgs-linux.fetchFromGitHub {
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
            prog = "${pkgs-linux.nuclei}/bin/nuclei -ud /home/sprrw/.local/nuclei-templates -duc";
          };

        sqlmap = mkSandbox {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.sqlmap}/bin/sqlmap";
        };

        feroxbuster = mkSandbox {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.feroxbuster}/bin/feroxbuster";
        };

        ffuf = mkSandbox {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.ffuf}/bin/ffuf";
        };

        shortscan = mkSandbox {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.shortscan}/bin/shortscan";
        };

        gau = mkSandbox {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.gau}/bin/gau";
        };

        naabu = mkSandbox {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.naabu}/bin/naabu";
        };

        clairvoyance = mkSandbox {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.clairvoyance}/bin/clairvoyance";
        };

        sourcemapper = mkSandbox {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.sourcemapper}/bin/sourcemapper";
        };

        subfinder = mkSandbox {
          name = "subfinder";
          shareCwd = true;
          network = true;
          prog = "${pkgs-linux.subfinder}/bin/subfinder";
        };

        mitmproxy = mkSandbox {
          name = "mitmproxy";
          prog = "${pkgs-linux.mitmproxy}/bin/mitmproxy";
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
          prog = "${pkgs-linux.ilspycmd}/bin/ilspycmd";
        };
      };
    };
}
