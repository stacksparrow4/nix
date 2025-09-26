{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.php.enable = lib.mkEnableOption "php";
  };

  config = lib.mkIf config.sprrw.programming.php.enable {
    home.packages = with pkgs; [
      php
    ];
  };
}
