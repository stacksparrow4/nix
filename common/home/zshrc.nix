{ config, lib, ... }:

let cfg = config.sprrw.zshrc; in {
  options.sprrw.zshrc = {
    enable = lib.mkEnableOption "zshrc";
  };

  config = lib.mkIf cfg.enable {
    home.file.".zshrc".text = ''
      autoload -U colors && colors
      export PS1="%{$fg[blue]%}%1d %{$reset_color%}$ "

      bindkey "\e[1;3C" emacs-forward-word
      bindkey "\e[1;3D" emacs-backward-word
    '' + "\n" + (builtins.readFile ./aliases.sh);
  };
}
