{
  programs.tmux = {
    enable = true;

    extraConfig = builtins.readFile ./dotfiles/tmux/tmux.conf;
  };
}
