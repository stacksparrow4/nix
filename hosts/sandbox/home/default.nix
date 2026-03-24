{ pkgs, lib, config, ... }:

{
  imports = [
    ../../../common/home
  ];


  sprrw = {
  };

  home = {
    username = "sprrw";
    homeDirectory = "/home/sprrw";
  };
}
