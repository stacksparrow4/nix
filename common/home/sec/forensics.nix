{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.forensics.enable = lib.mkEnableOption "forensics";
  };

  config = lib.mkIf config.sprrw.sec.forensics.enable {
    home.packages = with pkgs; [
      (config.sprrw.sandboxing.runDockerBin { binName = "exiftool"; beforeTargetArgs = config.sprrw.sandboxing.recipes.pwd_starter; afterTargetArgs = "${exiftool}/bin/exiftool"; })
      (config.sprrw.sandboxing.runDockerBin { binName = "binwalk"; beforeTargetArgs = config.sprrw.sandboxing.recipes.pwd_starter; afterTargetArgs = "${binwalk}/bin/binwalk"; })
      (config.sprrw.sandboxing.runDockerBin { binName = "ent"; beforeTargetArgs = config.sprrw.sandboxing.recipes.pwd_starter; afterTargetArgs = "${ent}/bin/ent"; })
      wireshark
      tcpdump
    ];
  };
}
