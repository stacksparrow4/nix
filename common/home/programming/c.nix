{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.c.enable = lib.mkEnableOption "c";
  };

  config = lib.mkIf config.sprrw.programming.c.enable {
    home.packages = with pkgs; [
      gcc
      gnumake
      clang-tools
      cmake
      cmake-language-server
    ];
  };
}
