{ pkgs, lib, inputs, ... }:

{
  imports = [
    ../../../common/home
  ];


  sprrw = {
    linux.enable = true;
    nvim.enable = true;
    programming.enable = true;
    programming.sage.enable = lib.mkForce true;
    sec.enable = true;
    term.enable = true;
    gui.enable = true;
    sandboxing.enable = false;
    docker-config.enable = true;
  };

  home = {
    packages = with pkgs; [
      signal-desktop-bin
      lmms
      audacity
      aseprite
    ];


    username = "sprrw";
    homeDirectory = "/home/sprrw";

    file.".background-image".source = ../bg.png;

    file.".config/i3/config".text = ''
      # class                 border  backgr. text    indicator child_border
      client.focused          #4c7899 #285577 #ffffff #285577   #285577
      client.focused_inactive #333333 #5f676a #ffffff #5f676a   #5f676a
      client.unfocused        #333333 #222222 #888888 #222222   #222222
      client.urgent           #2f343a #900000 #ffffff #900000   #900000
      client.placeholder      #000000 #0c0c0c #ffffff #0c0c0c   #0c0c0c

      client.background       #ffffff
    '';
  };
}
