{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.forensics.enable = lib.mkEnableOption "forensics";
  };

  config = lib.mkIf config.sprrw.sec.forensics.enable {
    home.packages = with pkgs; [
      (mkSandbox {
        name = "exiftool";
        type = "bwrap";
        shareCwd = true;
        prog = "${exiftool}/bin/exiftool";
      })
      (mkSandbox {
        name = "binwalk";
        type = "bwrap";
        shareCwd = true;
        prog = "${binwalk}/bin/binwalk";
      })
      (mkSandbox {
        name = "ent";
        type = "bwrap";
        shareCwd = true;
        prog = "${ent}/bin/ent";
      })
      tcpdump
    ];
  };
}
