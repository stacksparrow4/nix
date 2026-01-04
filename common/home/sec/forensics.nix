{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.forensics.enable = lib.mkEnableOption "forensics";
  };

  config = lib.mkIf config.sprrw.sec.forensics.enable {
    home.packages = with pkgs; [
      exiftool
      binwalk
      ent
      wireshark
    ];
  };
}
