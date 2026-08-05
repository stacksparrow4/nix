{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.cracking.enable = lib.mkEnableOption "cracking";
  };

  config = lib.mkIf config.sprrw.sec.cracking.enable {
    home.packages = (with pkgs; [
      hashcat
      john
    ])
    ++ [ self'.packages.hydra ];
  };
}
