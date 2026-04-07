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
        (config.sprrw.sandboxing.runDockerBin {
          # TODO: mount ~/nuclei-templates to ~/.local/share/nuclei-templates or something
          name = "nuclei";
          args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${nuclei}/bin/nuclei";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "sqlmap";
          args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${sqlmap}/bin/sqlmap";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "feroxbuster";
          args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${feroxbuster}/bin/feroxbuster";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "ffuf";
          args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${ffuf}/bin/ffuf";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "shortscan";
          args = "DOCKERIMG ${shortscan}/bin/shortscan";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "gau";
          args = "DOCKERIMG ${gau}/bin/gau";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "naabu";
          args = "-it DOCKERIMG ${naabu}/bin/naabu";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "clairvoyance";
          args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${clairvoyance}/bin/clairvoyance";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "sourcemapper";
          args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${sourcemapper}/bin/sourcemapper";
        })
        (config.sprrw.sandboxing.runDockerBin {
          name = "subfinder";
          args = "-it DOCKERIMG ${subfinder}/bin/subfinder";
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
          config.sprrw.sandboxing.runDockerBin {
            name = "vulnx";
            args = "DOCKERIMG ${vulnx}/bin/vulnx";
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
          pkgs.writeShellApplication {
            name = "smuggler";
            text = ''
              mkdir -p payloads
              ${config.sprrw.sandboxing.runDocker} -it -v "$(pwd)/payloads:/payloads" DOCKERIMG ${smugglerWrapped}/bin/smuggler "$@"
            '';
          }
        )
      ];
  };
}
