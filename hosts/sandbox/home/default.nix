{ lib, ... }:

{
  imports = [
    ../../../common/home
  ];

  sprrw = {
    ai.enable = true;
    linux.term.enable = true;
    nvim.enable = true;
    programming.enable = true;
    sec.enable = true;
    term = {
      enable = true;
      ghostty.enable = lib.mkForce false;
    };
  };

  home = {
    username = "sprrw";
    homeDirectory = "/home/sprrw";
  };
}
