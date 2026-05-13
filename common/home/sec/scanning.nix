{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.scanning.enable = lib.mkEnableOption "scanning";
  };

  config = lib.mkIf config.sprrw.sec.scanning.enable {
    home.packages =
      with pkgs;
      [
        nmap
        masscan
        rustscan
        (mkSandbox {
          name = "nuclei";
          sharedPaths = [
            {
              hostPath = "$HOME/.local/nuclei-templates";
              boxPath = "/home/sprrw/.local/nuclei-templates";
              ro = false;
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
          prog = "${nuclei}/bin/nuclei -ud /home/sprrw/.local/nuclei-templates -duc";
        })
        (mkSandbox {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${sqlmap}/bin/sqlmap";
        })
        (mkSandbox {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${feroxbuster}/bin/feroxbuster";
        })
        (mkSandbox {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${ffuf}/bin/ffuf";
        })
        (mkSandbox {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${shortscan}/bin/shortscan";
        })
        (mkSandbox {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${gau}/bin/gau";
        })
        (mkSandbox {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${naabu}/bin/naabu";
        })
        (mkSandbox {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${clairvoyance}/bin/clairvoyance";
        })
        (mkSandbox {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${sourcemapper}/bin/sourcemapper";
        })
        (mkSandbox {
          name = "subfinder";
          shareCwd = true;
          network = true;
          prog = "${subfinder}/bin/subfinder";
        })
      ]
      ++ [
        # pkgs that aren't from nixpkgs
        (
          let
            vulnx = pkgs.callPackage (
              {
                buildGoModule,
                fetchFromGitHub,
              }:
              buildGoModule {
                pname = "cvemap";
                version = "1.0.0";

                src = fetchFromGitHub {
                  owner = "projectdiscovery";
                  repo = "cvemap";
                  rev = "7cda1d46d51d6476eb878e70c2c8deac6ac39a8e";
                  hash = "sha256-dBizKJDVwu5TBNKXAPiLnFXmg5CXJMeLnDX/kguarFg=";
                };

                vendorHash = "sha256-2Y8alMa0prLL+Id3np+/iuYAZMPQnvR80Rr3LONSSUU=";

                subPackages = [
                  "cmd/vulnx/"
                ];

                ldflags = [
                  "-s"
                  "-w"
                ];
              }
            ) { };
          in
          mkSandbox {
            name = "vulnx";
            network = true;
            prog = "${vulnx}/bin/vulnx";
          }
        )
        (
          let
            smugglerSrc = pkgs.fetchFromGitHub {
              owner = "defparam";
              repo = "smuggler";
              rev = "2be871e6151ce85167a277fab21c74c851d8b20b";
              hash = "sha256-ctRx81DL5orVioB+d22qSsEe9m5+CLU7VqmRmLBN4xs=";
            };
            smugglerSrcWithPayloadsLink = pkgs.runCommand "smuggler-src-linked" { } ''
              mkdir $out
              cd $out
              cp -r ${smugglerSrc}/* .
              chmod -R 755 .
              rm -rf payloads
              ln -s /payloads payloads
            '';
            smugglerWrapped = pkgs.writeShellApplication {
              name = "smuggler";
              text = ''
                ${pkgs.python313}/bin/python3 ${smugglerSrcWithPayloadsLink}/smuggler.py "$@"
              '';
            };
          in
          mkSandbox {
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
            prog = "${smugglerWrapped}/bin/smuggler";
          }
        )
      ];
  };
}
