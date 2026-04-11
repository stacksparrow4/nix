{
  config,
  lib,
  pkgs,
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
        (config.sprrw.sandbox.create {
          # TODO: mount ~/nuclei-templates to ~/.local/share/nuclei-templates or something
          name = "nuclei";
          shareCwd = true;
          network = true;
          prog = "${nuclei}/bin/nuclei";
        })
        (config.sprrw.sandbox.create {
          name = "sqlmap";
          shareCwd = true;
          network = true;
          prog = "${sqlmap}/bin/sqlmap";
        })
        (config.sprrw.sandbox.create {
          name = "feroxbuster";
          shareCwd = true;
          network = true;
          prog = "${feroxbuster}/bin/feroxbuster";
        })
        (config.sprrw.sandbox.create {
          name = "ffuf";
          shareCwd = true;
          network = true;
          prog = "${ffuf}/bin/ffuf";
        })
        (config.sprrw.sandbox.create {
          name = "shortscan";
          shareCwd = true;
          network = true;
          prog = "${shortscan}/bin/shortscan";
        })
        (config.sprrw.sandbox.create {
          name = "gau";
          shareCwd = true;
          network = true;
          prog = "${gau}/bin/gau";
        })
        (config.sprrw.sandbox.create {
          name = "naabu";
          shareCwd = true;
          network = true;
          prog = "${naabu}/bin/naabu";
        })
        (config.sprrw.sandbox.create {
          name = "clairvoyance";
          shareCwd = true;
          network = true;
          prog = "${clairvoyance}/bin/clairvoyance";
        })
        (config.sprrw.sandbox.create {
          name = "sourcemapper";
          shareCwd = true;
          network = true;
          prog = "${sourcemapper}/bin/sourcemapper";
        })
        (config.sprrw.sandbox.create {
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
          config.sprrw.sandbox.create {
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
          config.sprrw.sandbox.create {
            name = "smuggler";
            sharedPaths = [
              { hostPath = "$(pwd)/payloads"; boxPath = "/payloads"; ro = false; type = "dir"; }
            ];
            network = true;
            prog = "${smugglerWrapped}/bin/smuggler";
          }
        )
      ];
  };
}
