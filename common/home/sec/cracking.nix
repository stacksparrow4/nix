{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.cracking.enable = lib.mkEnableOption "cracking";
  };

  config = lib.mkIf config.sprrw.sec.cracking.enable {
    home.packages = with pkgs; [
      hashcat
      john
      (config.sprrw.sandboxing.runDockerBin { binName = "hydra"; beforeTargetArgs = config.sprrw.sandboxing.recipes.pwd_starter; afterTargetArgs = "${thc-hydra}/bin/hydra"; })
    ];
  };
}
