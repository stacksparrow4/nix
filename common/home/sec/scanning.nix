{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.scanning.enable = lib.mkEnableOption "scanning";
  };

  config = let
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
    ) {};
    smugglerSrc = pkgs.fetchFromGitHub {
      owner = "defparam";
      repo = "smuggler";
      rev = "2be871e6151ce85167a277fab21c74c851d8b20b";
      hash = "sha256-ctRx81DL5orVioB+d22qSsEe9m5+CLU7VqmRmLBN4xs=";
    };
    smugglerSrcWithPayloadsLink = pkgs.runCommand "smuggler-src-linked" {} ''
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
    smugglerDocker = config.sprrw.sandboxing.runDockerBin {
      name = "smuggler";
      args = "-it -v \"$(pwd)/payloads:/payloads\" DOCKERIMG ${smugglerWrapped}/bin/smuggler";
    };
    smuggler = pkgs.writeShellApplication {
      name = "smuggler";
      text = ''
        mkdir -p payloads
        ${smugglerDocker}/bin/smuggler "$@"
      '';
    };
  in lib.mkIf config.sprrw.sec.scanning.enable {
    home.packages = with pkgs; [
      nmap
      masscan
      rustscan
      (config.sprrw.sandboxing.runDockerBin { name = "nuclei"; args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${nuclei}/bin/nuclei"; })
      (config.sprrw.sandboxing.runDockerBin { name = "sqlmap"; args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${sqlmap}/bin/sqlmap"; })
      (config.sprrw.sandboxing.runDockerBin { name = "feroxbuster"; args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${feroxbuster}/bin/feroxbuster"; })
      (config.sprrw.sandboxing.runDockerBin { name = "ffuf"; args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${ffuf}/bin/ffuf"; })
    ] ++ [ # pkgs that aren't from nixpkgs
      (config.sprrw.sandboxing.runDockerBin { name = "vulnx"; args = "DOCKERIMG ${vulnx}/bin/vulnx"; })
      (config.sprrw.sandboxing.runDockerBin { name = "shortscan"; args = "DOCKERIMG ${pkgs.shortscan}/bin/shortscan"; })
      (config.sprrw.sandboxing.runDockerBin { name = "gau"; args = "DOCKERIMG ${pkgs.gau}/bin/gau"; })
      smuggler
    ];
  };
}
