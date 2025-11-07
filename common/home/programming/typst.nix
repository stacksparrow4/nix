{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.typst.enable = lib.mkEnableOption "typst";
  };

  config = lib.mkIf config.sprrw.programming.typst.enable {
    home.packages = with pkgs; [
      tinymist
      typstyle
    ];
  };
}
