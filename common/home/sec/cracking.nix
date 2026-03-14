{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.cracking.enable = lib.mkEnableOption "cracking";
  };

  config = lib.mkIf config.sprrw.sec.cracking.enable {
    home.packages = with pkgs; [
      hashcat
      john
      (config.sprrw.sandboxing.runDockerBin { name = "hydra"; args = "${config.sprrw.sandboxing.recipes.pwd_starter} DOCKERIMG ${thc-hydra}/bin/hydra"; })
    ];
  };
}
