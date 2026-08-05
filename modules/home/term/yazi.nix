{
  # Portable yazi config. The Linux-only openers and mime associations live in
  # `term-yazi-linux`.
  flake.homeModules.term-yazi = {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";

      keymap = {
        mgr.prepend_keymap = [
          {
            run = "quit";
            on = [ "<Esc>" ];
          }
          {
            run = "remove --permanently";
            on = [ "d" ];
          }
        ];

        spot.prepend_keymap = [
          {
            on = "q";
            run = "close";
          }
        ];
      };
    };
  };
}
