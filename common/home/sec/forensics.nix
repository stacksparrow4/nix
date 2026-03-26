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
      (config.sprrw.sandboxing.runDockerBin {
        name = "exiftool";
        args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${exiftool}/bin/exiftool";
      })
      (config.sprrw.sandboxing.runDockerBin {
        name = "binwalk";
        args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${binwalk}/bin/binwalk";
      })
      (config.sprrw.sandboxing.runDockerBin {
        name = "ent";
        args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${ent}/bin/ent";
      })
      tcpdump
    ];
  };
}
