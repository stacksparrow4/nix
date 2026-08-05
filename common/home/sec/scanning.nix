{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.scanning.enable = lib.mkEnableOption "scanning";
  };

  config = lib.mkIf config.sprrw.sec.scanning.enable {
    home.packages =
      (with pkgs; [
        nmap
        masscan
        rustscan
      ])
      ++ (with self'.packages; [
        nuclei
        sqlmap
        feroxbuster
        ffuf
        shortscan
        gau
        naabu
        clairvoyance
        sourcemapper
        subfinder
        vulnx
        smuggler
      ]);
  };
}
