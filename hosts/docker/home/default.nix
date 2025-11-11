{ lib, ... }:

{
  imports = [
     ../../../common/home
  ];

  home = {
    username = "root";
    homeDirectory = "/root";
  };

  sprrw = {
    linux.term.enable = true;
    nvim.enable = true;
    programming.enable = true;
    sec.enable = true;
    sec.burp.enable = lib.mkForce false;
    sec.caido.enable = lib.mkForce false;
    sec.pwn.enable = lib.mkForce false; # pwndbg takes a while to install
    term.enable = true;
    term.alacritty.enable = lib.mkForce false;
    term.alacritty.installTerminfo = true;
    term.bash.ps1 = ''\n\[\033[1;34m\] \W \$\[\033[0m\] '';
  };
}
