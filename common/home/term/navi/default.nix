{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.term.navi.enable = lib.mkEnableOption "navi";
  };

  config = lib.mkIf config.sprrw.term.navi.enable {
    home.packages = with pkgs; [ navi ];

    home.file.".local/share/navi/cheats".source = ./cheats;
  };
}
