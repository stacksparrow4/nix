{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.node.enable = lib.mkEnableOption "node";
  };

  config = lib.mkIf config.sprrw.programming.node.enable {
    home.packages = with pkgs; [
      nodejs_22
      typescript-language-server
    ];
  };
}
