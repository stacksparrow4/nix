{
  perSystem =
    { pkgs, config, ... }:
    {
      wrappers.mkSandbox =
        {
          name,
          outsideBeforeScript ? "",
          prog, # path to the program. Will be called with forwarded arguments
          shareCwd ? false,
          sharedPaths ? [ ], # { hostPath, boxPath, ro ? false, type = "dir"|"file", needsCreate ? true }. Can contain shell characters such as $() but will be wrapped in double quotes
          downgradeTerm ? false, # sets term to xterm-256color for tools that don't support terminfo
          network ? false,
          wayland ? false,
          x11 ? false,
          roDotGit ? false,
        }:
        let
          backslashify =
            arr:
            if (builtins.length arr) == 0 then
              "\\"
            else
              builtins.concatStringsSep "\n  " (map (x: "${x} \\") arr);
        in
        pkgs.writeShellApplication {
          inherit name;
          text = ''
            ${outsideBeforeScript}

            ${config.packages.box}/bin/box \
              ${backslashify (
                (if shareCwd then [ "--cwd" ] else [ ])
                ++ (builtins.concatMap (
                  {
                    hostPath,
                    boxPath,
                    ro ? false,
                    type,
                  }:
                  [
                    "-v"
                    "\"${hostPath}:${boxPath}:${if ro then "ro" else "rw"}:${type}\""
                  ]
                ) sharedPaths)
                ++ (if downgradeTerm then [ "--downgrade-term" ] else [ ])
                ++ (if network then [ ] else [ "--no-network" ])
                ++ (if wayland then [ "--wayland" ] else [ ])
                ++ (if x11 then [ "--x11" ] else [ ])
                ++ (if roDotGit then [ "--ro-git" ] else [ ])
              )}
              -- ${prog} "$@"
          '';
        };
    };
}
