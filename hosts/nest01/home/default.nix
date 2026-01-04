{ pkgs, inputs, ... }:

{
  imports = [
    ../../../common/home
  ];


    sprrw = {
      linux.enable = true;
      nvim.enable = true;
      programming.enable = true;
      sec.enable = true;
      term.enable = true;
      gui.enable = true;
      sandboxing.enable = true;
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
      # Start i3bar to display a workspace bar (plus the system information i3status
      # finds out, if available)
      bar {
            position top
            status_command i3blocks
      }

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
