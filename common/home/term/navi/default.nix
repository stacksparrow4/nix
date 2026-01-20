{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.term.navi.enable = lib.mkEnableOption "navi";
  };

  config = lib.mkIf config.sprrw.term.navi.enable {
    home.packages = with pkgs; [ navi ];

    home.file.".local/share/navi/cheats".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/term/navi/cheats";
  };
}
