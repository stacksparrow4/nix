{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.forensics.enable = lib.mkEnableOption "forensics";
  };

  config = lib.mkIf config.sprrw.sec.forensics.enable {
    home.packages = (with self'.packages; [
      exiftool
      binwalk
      ent
    ])
    ++ [ pkgs.tcpdump ];
  };
}
