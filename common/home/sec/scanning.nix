{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.scanning.enable = lib.mkEnableOption "scanning";
  };

  config = lib.mkIf config.sprrw.sec.scanning.enable {
    home.packages = with pkgs; [
      nmap
      rustscan
      nuclei
      sqlmap
      feroxbuster
      ffuf
    ];
  };
}
