{
  perSystem =
    {
      pkgsLinux,
      pkgsLinuxUnstable,
      config,
      ...
    }:
    {
      packages = {
        bx = config.wrappers.mkSandbox {
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

        nodemon = config.wrappers.mkSandbox {
          name = "nodemon";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.nodemon}/bin/nodemon";
        };

        tailcat = config.wrappers.mkSandbox {
          name = "tailcat";
          network = true;
          prog = "${pkgsLinuxUnstable.tailcat}/bin/tailcat";
        };

        wlfreerdp = config.wrappers.mkSandbox {
          name = "wlfreerdp";
          wayland = true;
          network = true;
          prog = "${pkgsLinux.freerdp}/bin/wlfreerdp";
        };

        sage = config.wrappers.mkSandbox {
          name = "sage";
          shareCwd = true;
          prog = "${pkgsLinux.sage}/bin/sage";
        };

        shtris = config.wrappers.mkSandbox {
          name = "shtris";
          prog = "${pkgsLinux.shtris}/bin/shtris";
        };

        zbarimg = config.wrappers.mkSandbox {
          name = "zbarimg";
          prog = "${pkgsLinux.zbar}/bin/zbarimg";
        };

        twitch-dl = config.wrappers.mkSandbox {
          name = "twitch-dl";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.twitch-dl}/bin/twitch-dl";
        };

        yt-dlp = config.wrappers.mkSandbox {
          name = "yt-dlp";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.yt-dlp}/bin/yt-dlp";
        };

        exiftool = config.wrappers.mkSandbox {
          name = "exiftool";
          prog = "${pkgsLinux.exiftool}/bin/exiftool";
          shareCwd = true;
        };

        binwalk = config.wrappers.mkSandbox {
          name = "binwalk";
          prog = "${pkgsLinux.binwalk}/bin/binwalk";
          shareCwd = true;
        };

        ent = config.wrappers.mkSandbox {
          name = "ent";
          prog = "${pkgsLinux.ent}/bin/ent";
          shareCwd = true;
        };

        apktool = config.wrappers.mkSandbox {
          name = "apktool";
          shareCwd = true;
          prog = "${pkgsLinux.apktool}/bin/apktool";
        };

        jadx = config.wrappers.mkSandbox {
          name = "jadx";
          shareCwd = true;
          prog = "${pkgsLinux.jadx}/bin/jadx";
        };

        hydra = config.wrappers.mkSandbox {
          name = "hydra";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.thc-hydra}/bin/hydra";
        };

        pwninit = config.wrappers.mkSandbox {
          name = "pwninit";
          shareCwd = true;
          prog = "${pkgsLinux.pwninit}/bin/pwninit";
        };

        ropr = config.wrappers.mkSandbox {
          name = "ropr";
          shareCwd = true;
          prog = "${pkgsLinux.ropr}/bin/ropr";
        };

        ROPgadget = config.wrappers.mkSandbox {
          name = "ROPgadget";
          shareCwd = true;
          prog = "${pkgsLinux.ropgadget}/bin/ROPgadget";
        };

        snmpwalk = config.wrappers.mkSandbox {
          name = "snmpwalk";
          network = true;
          prog = "${pkgsLinux.net-snmp}/bin/snmpwalk";
        };

        snmpcheck = config.wrappers.mkSandbox {
          name = "snmpcheck";
          network = true;
          prog = "${pkgsLinux.snmpcheck}/bin/snmpcheck";
        };

        evil-winrm = config.wrappers.mkSandbox {
          name = "evil-winrm";
          prog = "${pkgsLinux.evil-winrm}/bin/evil-winrm";
          network = true;
        };

        certipy = config.wrappers.mkSandbox {
          name = "certipy";
          prog = "${pkgsLinux.certipy}/bin/certipy";
          shareCwd = true;
          network = true;
        };

        bloodyAD = config.wrappers.mkSandbox {
          name = "bloodyAD";
          prog = "${pkgsLinux.python312Packages.bloodyad}/bloodyAD";
          shareCwd = true;
          network = true;
        };

        pwsh = config.wrappers.mkSandbox {
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
          config.wrappers.mkSandbox {
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

        sqlmap = config.wrappers.mkSandbox {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.sqlmap}/bin/sqlmap";
        };

        feroxbuster = config.wrappers.mkSandbox {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.feroxbuster}/bin/feroxbuster";
        };

        ffuf = config.wrappers.mkSandbox {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.ffuf}/bin/ffuf";
        };

        shortscan = config.wrappers.mkSandbox {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.shortscan}/bin/shortscan";
        };

        gau = config.wrappers.mkSandbox {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.gau}/bin/gau";
        };

        naabu = config.wrappers.mkSandbox {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.naabu}/bin/naabu";
        };

        clairvoyance = config.wrappers.mkSandbox {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.clairvoyance}/bin/clairvoyance";
        };

        sourcemapper = config.wrappers.mkSandbox {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.sourcemapper}/bin/sourcemapper";
        };

        subfinder = config.wrappers.mkSandbox {
          name = "subfinder";
          shareCwd = true;
          network = true;
          prog = "${pkgsLinux.subfinder}/bin/subfinder";
        };

        mitmproxy = config.wrappers.mkSandbox {
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

        ilspycmd = config.wrappers.mkSandbox {
          name = "ilspycmd";
          shareCwd = true;
          prog = "${pkgsLinux.ilspycmd}/bin/ilspycmd";
        };
      };
    };
}
