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
  in lib.mkIf config.sprrw.sec.scanning.enable {
    home.packages = with pkgs; [
      nmap
      rustscan
      nuclei
      sqlmap
      feroxbuster
      ffuf
      vulnx
    ];
  };
}
