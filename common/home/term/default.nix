{ lib, config, ... }:

{
  imports = [
    ./alacritty.nix
    ./ghostty.nix
    ./bash.nix
    ./basic.nix
    ./large.nix
    ./navi
    ./tmux
    ./zshrc.nix
  ];

  options = {
    sprrw.term.enable = lib.mkEnableOption "term";
  };

  config = lib.mkIf config.sprrw.term.enable {
    sprrw.term.alacritty.enable = true; # TODO: only with GUI?
    sprrw.term.ghostty.enable = true; # TODO: only with GUI?
    sprrw.term.basic.enable = true;
    sprrw.term.large.enable = true;
    sprrw.term.navi.enable = true;
    sprrw.term.tmux.enable = true;
    sprrw.term.zshrc.enable = true;
  };
}
