{
  flake.homeModules.term-yazi-linux = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications."inode/directory" = "yazi.desktop";
    };

    programs.yazi = {
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

      keymap.mgr.prepend_keymap = [
        {
          run = "shell 'dragon-drop \"$@\"' --confirm";
          on = [ "D" ];
        }
      ];
    };
  };
}
