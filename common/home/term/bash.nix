{ config, lib, ... }:

{
  options.sprrw.term.bash = {
    ps1 = lib.mkOption {
      type = lib.types.str;
      default = ''\n\[\033[1;32m\] \W \$\[\033[0m\] '';
    };
  };

  config = let
    cfg = config.sprrw.term.bash;
  in {
    programs.bash = {
      enable = true;
      bashrcExtra = (builtins.readFile ./aliases.sh) + "eval \"$(navi widget bash)\"\nexport PS1='" + cfg.ps1 + "'";
    };

    home.file.".bash_profile".text = ''
      if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
      fi
    '';
  };
}
