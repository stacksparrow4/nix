{ config, lib, ... }:

{
  options.sprrw.term.zshrc = {
    enable = lib.mkEnableOption "zshrc";
  };

  config =
    let
      cfg = config.sprrw.term.zshrc;
    in
    lib.mkIf cfg.enable {
      home.file.".zshrc".text = ''
        autoload -U colors && colors
        export PS1="%{$fg[blue]%}%1d %{$reset_color%}$ "
        export EDITOR=nvim

        bindkey "\e[1;3C" emacs-forward-word
        bindkey "\e[1;3D" emacs-backward-word
      ''
      + "\n"
      + config.sprrw.term.shellExtra;
    };
}
