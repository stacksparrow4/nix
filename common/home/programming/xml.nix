{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.xml.enable = lib.mkEnableOption "xml";
  };

  config = lib.mkIf config.sprrw.programming.xml.enable {
    home.packages = with pkgs; [
      lemminx
    ];
  };
}
