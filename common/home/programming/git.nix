{ config, lib, ... }:

{
  options = {
    sprrw.programming.git.enable = lib.mkEnableOption "git";
  };

  config = lib.mkIf config.sprrw.programming.git.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          email = "stacksparrow4@gmail.com";
          name = "Daniel Cooper";
        };
        safe.bareRepository = "explicit";
      };
    };

    sprrw.term.shellExtra = ''
      alias ggpush='git push -u origin $(git branch --show-current)'
      alias ggpull='git pull'
      alias ga='git add'
      alias gd='git diff'
      alias gds='git diff --staged'
      alias gcmsg='git commit -m'
      alias gacmsg='git add . && git commit -m'
      alias gamsg='git add . && git commit -m'
      alias gco='git checkout'
      alias gcb='git checkout -b'
      alias gst='git status'
      alias gcm='git checkout main || git checkout master'
      alias glog='git log'
      alias gds='git diff --staged'
      alias gf='git fetch'
      alias grv='git remote -v'
      alias gbv='git branch -v'
    '';
  };
}
