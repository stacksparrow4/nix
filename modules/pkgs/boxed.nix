{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      packages = {
        bx = self'.wrappers.mkSandbox {
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
          prog = "${pkgs.brave-search-cli}/bin/bx";
        };

        nodemon = self'.wrappers.mkSandbox {
          name = "nodemon";
          shareCwd = true;
          network = true;
          prog = "${pkgs.nodemon}/bin/nodemon";
        };

        wlfreerdp = self'.wrappers.mkSandbox {
          name = "wlfreerdp";
          wayland = true;
          network = true;
          prog = "${pkgs.freerdp}/bin/wlfreerdp";
        };

        sage = self'.wrappers.mkSandbox {
          name = "sage";
          shareCwd = true;
          prog = "${pkgs.sage}/bin/sage";
        };

        shtris = self'.wrappers.mkSandbox {
          name = "shtris";
          prog = "${pkgs.shtris}/bin/shtris";
        };

        zbarimg = self'.wrappers.mkSandbox {
          name = "zbarimg";
          prog = "${pkgs.zbar}/bin/zbarimg";
        };

        twitch-dl = self'.wrappers.mkSandbox {
          name = "twitch-dl";
          shareCwd = true;
          network = true;
          prog = "${pkgs.twitch-dl}/bin/twitch-dl";
        };

        yt-dlp = self'.wrappers.mkSandbox {
          name = "yt-dlp";
          shareCwd = true;
          network = true;
          prog = "${pkgs.yt-dlp}/bin/yt-dlp";
        };

        exiftool = self'.wrappers.mkSandbox {
          name = "exiftool";
          prog = "${pkgs.exiftool}/bin/exiftool";
          shareCwd = true;
        };

        binwalk = self'.wrappers.mkSandbox {
          name = "binwalk";
          prog = "${pkgs.binwalk}/bin/binwalk";
          shareCwd = true;
        };

        ent = self'.wrappers.mkSandbox {
          name = "ent";
          prog = "${pkgs.ent}/bin/ent";
          shareCwd = true;
        };

        apktool = self'.wrappers.mkSandbox {
          name = "apktool";
          shareCwd = true;
          prog = "${pkgs.apktool}/bin/apktool";
        };

        jadx = self'.wrappers.mkSandbox {
          name = "jadx";
          shareCwd = true;
          prog = "${pkgs.jadx}/bin/jadx";
        };

        hydra = self'.wrappers.mkSandbox {
          name = "hydra";
          shareCwd = true;
          network = true;
          prog = "${pkgs.thc-hydra}/bin/hydra";
        };

        pwninit = self'.wrappers.mkSandbox {
          name = "pwninit";
          shareCwd = true;
          prog = "${pkgs.pwninit}/bin/pwninit";
        };

        ropr = self'.wrappers.mkSandbox {
          name = "ropr";
          shareCwd = true;
          prog = "${pkgs.ropr}/bin/ropr";
        };

        ROPgadget = self'.wrappers.mkSandbox {
          name = "ROPgadget";
          shareCwd = true;
          prog = "${pkgs.ropgadget}/bin/ROPgadget";
        };

        snmpwalk = self'.wrappers.mkSandbox {
          name = "snmpwalk";
          network = true;
          prog = "${pkgs.net-snmp}/bin/snmpwalk";
        };

        snmpcheck = self'.wrappers.mkSandbox {
          name = "snmpcheck";
          network = true;
          prog = "${pkgs.snmpcheck}/bin/snmpcheck";
        };

        evil-winrm = self'.wrappers.mkSandbox {
          name = "evil-winrm";
          prog = "${pkgs.evil-winrm}/bin/evil-winrm";
          network = true;
        };

        certipy = self'.wrappers.mkSandbox {
          name = "certipy";
          prog = "${pkgs.certipy}/bin/certipy";
          shareCwd = true;
          network = true;
        };

        bloodyAD = self'.wrappers.mkSandbox {
          name = "bloodyAD";
          prog = "${pkgs.python312Packages.bloodyad}/bloodyAD";
          shareCwd = true;
          network = true;
        };

        pwsh = self'.wrappers.mkSandbox {
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
          self'.wrappers.mkSandbox {
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
            prog = "${pkgs.nuclei}/bin/nuclei -ud /home/sprrw/.local/nuclei-templates -duc";
          };

        sqlmap = self'.wrappers.mkSandbox {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${pkgs.sqlmap}/bin/sqlmap";
        };

        feroxbuster = self'.wrappers.mkSandbox {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${pkgs.feroxbuster}/bin/feroxbuster";
        };

        ffuf = self'.wrappers.mkSandbox {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${pkgs.ffuf}/bin/ffuf";
        };

        shortscan = self'.wrappers.mkSandbox {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${pkgs.shortscan}/bin/shortscan";
        };

        gau = self'.wrappers.mkSandbox {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${pkgs.gau}/bin/gau";
        };

        naabu = self'.wrappers.mkSandbox {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${pkgs.naabu}/bin/naabu";
        };

        clairvoyance = self'.wrappers.mkSandbox {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${pkgs.clairvoyance}/bin/clairvoyance";
        };

        sourcemapper = self'.wrappers.mkSandbox {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${pkgs.sourcemapper}/bin/sourcemapper";
        };

        subfinder = self'.wrappers.mkSandbox {
          name = "subfinder";
          shareCwd = true;
          network = true;
          prog = "${pkgs.subfinder}/bin/subfinder";
        };

        mitmproxy = self'.wrappers.mkSandbox {
          name = "mitmproxy";
          prog = "${pkgs.mitmproxy}/bin/mitmproxy";
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

        ilspycmd = self'.wrappers.mkSandbox {
          name = "ilspycmd";
          shareCwd = true;
          prog = "${pkgs.ilspycmd}/bin/ilspycmd";
        };

        qpdf = self'.wrappers.mkSandbox {
          name = "qpdf";
          shareCwd = true;
          prog = "${pkgs.qpdf}/bin/qpdf";
        };

        bat = self'.wrappers.mkSandbox {
          name = "bat";
          shareCwd = true;
          prog = "${pkgs.bat}/bin/bat";
        };
      };
    };
}
