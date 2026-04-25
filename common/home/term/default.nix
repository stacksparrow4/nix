{ lib, config, ... }:

{
  imports = [
    ./ghostty.nix
    ./bash.nix
    ./navi
    ./tmux
    ./yazi.nix
    ./zshrc.nix
    ./foot
  ];

  options = {
    sprrw.term.enable = lib.mkEnableOption "term";
  };

  config = lib.mkIf config.sprrw.term.enable {
    sprrw.term.ghostty.enable = false;
    sprrw.term.foot.enable = true;
    sprrw.term.navi.enable = true;
    sprrw.term.tmux.enable = true;
    sprrw.term.yazi.enable = true;
    sprrw.term.zshrc.enable = true;
  };
}
