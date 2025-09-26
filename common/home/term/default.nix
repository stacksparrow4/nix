{ lib, config, ... }:

{
  imports = [
    ./alacritty.nix
    ./bash.nix
    ./basic.nix
    ./large.nix
    ./linux.nix
    ./navi
    ./tmux
    ./zshrc.nix
  ];

  options = {
    sprrw.term.enable = lib.mkEnableOption "term";
  };

  config = lib.mkIf config.sprrw.term.enable {
    sprrw.term.alacritty.enable = true; # TODO: only with GUI?
    sprrw.term.bash.enable = true;
    sprrw.term.basic.enable = true;
    sprrw.term.large.enable = true;
    sprrw.term.linux.enable = true;
    sprrw.term.navi.enable = true;
    sprrw.term.tmux.enable = true;

    # note: not enabling zsh by default
  };
}
