{
  perSystem =
    {
      pkgs,
      lib,
      config,
      mkSandbox,
      ...
    }:
    let
      nucleiTemplates = pkgs.fetchFromGitHub {
        owner = "projectdiscovery";
        repo = "nuclei-templates";
        rev = "ee71c007b30bf63a44f500ffeebf11741324f7e2";
        hash = "sha256-MNx/RcGyvspH6qECuNqQ3mBYtsBMvH/w36IDbUAkyiA=";
      };

      boxCwdNetwork =
        name: prog:
        mkSandbox {
          inherit name prog;
          shareCwd = true;
          network = true;
        };
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nuclei = mkSandbox {
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

        sqlmap = boxCwdNetwork "sqlmap" "${pkgs.sqlmap}/bin/sqlmap";
        feroxbuster = boxCwdNetwork "feroxbuster" "${pkgs.feroxbuster}/bin/feroxbuster";
        ffuf = boxCwdNetwork "ffuf" "${pkgs.ffuf}/bin/ffuf";
        shortscan = boxCwdNetwork "shortscan" "${pkgs.shortscan}/bin/shortscan";
        gau = boxCwdNetwork "gau" "${pkgs.gau}/bin/gau";
        naabu = boxCwdNetwork "naabu" "${pkgs.naabu}/bin/naabu";
        clairvoyance = boxCwdNetwork "clairvoyance" "${pkgs.clairvoyance}/bin/clairvoyance";
        sourcemapper = boxCwdNetwork "sourcemapper" "${pkgs.sourcemapper}/bin/sourcemapper";
        subfinder = boxCwdNetwork "subfinder" "${pkgs.subfinder}/bin/subfinder";

        vulnx = mkSandbox {
          name = "vulnx";
          network = true;
          prog = "${config.packages.vulnx-unwrapped}/bin/vulnx";
        };

        smuggler = mkSandbox {
          name = "smuggler";
          sharedPaths = [
            {
              hostPath = "$(pwd)/payloads";
              boxPath = "/payloads";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${config.packages.smuggler-unwrapped}/bin/smuggler";
        };
      };
    };
}
