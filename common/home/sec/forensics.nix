{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.sec.forensics.enable = lib.mkEnableOption "forensics";
  };

  config = lib.mkIf config.sprrw.sec.forensics.enable {
    home.packages = with pkgs; [
      (config.sprrw.sandbox.create {
        name = "exiftool";
        type = "bwrap";
        shareCwd = true;
        prog = "${exiftool}/bin/exiftool";
      })
      (config.sprrw.sandbox.create {
        name = "binwalk";
        type = "bwrap";
        shareCwd = true;
        prog = "${binwalk}/bin/binwalk";
      })
      (config.sprrw.sandbox.create {
        name = "ent";
        type = "bwrap";
        shareCwd = true;
        prog = "${ent}/bin/ent";
      })
      tcpdump
    ];
  };
}
