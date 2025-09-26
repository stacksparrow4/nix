{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.lua.enable = lib.mkEnableOption "lua";
  };

  config = lib.mkIf config.sprrw.programming.lua.enable {
    home.packages = with pkgs; [
      lua-language-server
    ];
  };
}
