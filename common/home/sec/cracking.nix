{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.sec.cracking.enable = lib.mkEnableOption "cracking";
  };

  config = lib.mkIf config.sprrw.sec.cracking.enable {
    home.packages = with pkgs; [
      hashcat
      john
      (config.sprrw.sandbox.create {
        name = "hydra";
        shareCwd = true;
        network = true;
        prog = "${thc-hydra}/bin/hydra";
      })
    ];
  };
}
