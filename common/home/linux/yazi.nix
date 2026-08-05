{
  pkgs,
  lib,
  config,
  ...
}:

# Linux-only parts of the yazi config: xdg.mimeApps is Linux-only in
# home-manager, and the openers/keymaps below reference Linux-only tools
# (gimp, vlc, xdg-open, dragon-drop).
{
  config = lib.mkIf (config.sprrw.term.yazi.enable && pkgs.stdenv.hostPlatform.isLinux) {
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
