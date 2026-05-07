{ lib, ... }:

{
  imports = [
    ../../../common/home
  ];

  sprrw = {
    misc.enable = true;
    ai.enable = true;
    linux.term.enable = true;
    nvim.enable = true;
    programming.enable = true;
    sec = {
      enable = true;
      gui.enable = lib.mkForce false;
      caido.enable = lib.mkForce false;
    };
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
