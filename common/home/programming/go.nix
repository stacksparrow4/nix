{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.go.enable = lib.mkEnableOption "go";
  };

  config = lib.mkIf config.sprrw.programming.go.enable {
    home.packages = with pkgs; [
      go
      gopls
    ];
  };
}
