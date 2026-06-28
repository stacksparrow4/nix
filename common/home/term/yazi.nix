{
  lib,
  config,
  ...
}:

{
  options.sprrw.term.yazi.enable = lib.mkEnableOption "yazi";

  config = lib.mkIf config.sprrw.term.yazi.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";

      settings = {
        opener = {
          viewimg = [
            {
              run = "gimp \"$1\"";
              orphan = true;
              for = "unix";
            }
          ];

          viewvid = [
            {
              run = "vlc \"$1\"";
              orphan = true;
              for = "unix";
            }
          ];

          xdgopen = [
            {
              run = "xdg-open \"$1\"";
              orphan = true;
              for = "unix";
            }
          ];
        };

        open.prepend_rules = [
          {
            mime = "image/*";
            use = "viewimg";
          }
          {
            mime = "video/*";
            use = "viewvid";
          }
          {
            url = "*.docx";
            use = "xdgopen";
          }
          {
            url = "*.odt";
            use = "xdgopen";
          }
        ];
      };
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
          {
            run = "shell 'dragon-drop \"$@\"' --confirm";
            on = [ "D" ];
          }
        ];

        spot.prepend_keymap = [{
          on = "q";
          run = "close";
        }];
      };
    };
  };
}
