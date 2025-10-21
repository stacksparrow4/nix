{ pkgs, ... }:

{
  imports = [
     ../../../common/home
  ];

  home = {
    username = "root";
    homeDirectory = "/root";
  };

  sprrw = {
    nvim.enable = true;
    programming.enable = true;
    term.bash.ps1 = ''\n\[\033[1;34m\] \W \$\[\033[0m\] '';
  };
}
