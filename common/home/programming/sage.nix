{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.sage.enable = lib.mkEnableOption "sage";
  };

  config = lib.mkIf config.sprrw.programming.sage.enable {
    home.packages = with pkgs; [
      (sage.override {requireSageTests = false;})
    ];
  };
}
