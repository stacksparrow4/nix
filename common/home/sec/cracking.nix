{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.cracking.enable = lib.mkEnableOption "cracking";
  };

  config = lib.mkIf config.sprrw.sec.cracking.enable {
    home.packages = with pkgs; [
      hashcat
      john
      thc-hydra
    ];
  };
}
