{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  mkSandbox =
    {
      name,
      type ? "bwrap", # bwrap, docker/podman, vm
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
    assert type == "bwrap";
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        ${outsideBeforeScript}

        sandbox \
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
in
{
  options.sprrw.sandbox.enable = lib.mkEnableOption "sandboxing";

  config = {
    _module.args.mkSandbox = mkSandbox;

    home.packages = lib.mkIf config.sprrw.sandbox.enable [
      (import ../../pkgs/sandbox {
        inherit pkgs;
        inherit (inputs) crane;
      })
      (pkgs.writeShellApplication {
        name = "build-vm";
        text = ''
          cd ~/${config.sprrw.nixosRepoPath}
          git add .

          # Builds the ISO plus the kernel/initrd/cmdline needed to direct-boot
          # it, so `sandbox --vm` can skip the bootloader entirely.
          bootpath=$(nix build --no-link --print-out-paths .#vm-boot)
          echo "$bootpath"

          mkdir -p ~/.local

          ln -sfn "$bootpath" ~/.local/vm-boot
          # Kept for anything still expecting the raw image.
          ln -sfn "$bootpath/image.iso" ~/.local/vm.iso
        '';
      })
    ];

    sprrw.term.shellExtra = ''
      alias sbx='sandbox'
      alias box='sandbox'
      alias b='sandbox'
      alias bc='sandbox --cwd'
    '';
  };
}
