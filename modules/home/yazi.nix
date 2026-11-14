{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.yazi = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.yazi ];

      xdg.mimeApps = {
        enable = true;
        defaultApplications."inode/directory" = "yazi.desktop";
      };

      sprrw.term.shellExtra = ''
        function y() {
          local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
          command yazi "$@" --cwd-file="$tmp"
          if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
        }
      '';
    }
  );
}
