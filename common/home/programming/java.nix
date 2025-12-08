{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.java.enable = lib.mkEnableOption "java";
  };

  config = lib.mkIf config.sprrw.programming.java.enable {
    home.packages = with pkgs; [
      jdt-language-server
    ];
  };
}
