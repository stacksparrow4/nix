{
  pkgs,
  lib,
  config,
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
      (import ../../pkgs/sandbox { inherit pkgs; })
      (pkgs.writeShellApplication {
        name = "build-vm";
        text = ''
          cd ~/${config.sprrw.nixosRepoPath}
          git add .

          isopath=$(nixos-rebuild build-image --flake .#vm --image-variant iso --no-link)
          echo "$isopath"

          mkdir -p ~/.local

          rm -f ~/.local/vm.iso
          ln -s "$isopath" ~/.local/vm.iso
        '';
      })
      (pkgs.writeShellApplication {
        name = "vm-enter";
        text = ''
          ports=$(ss -tlpn | grep qemu-system | grep -oE '127\.0\.0\.1:[0-9]+' | cut -d: -f2)

          if [[ -z "$ports" ]]; then
            echo "No valid vms found"
            exit 1
          fi

          target=$(echo "$ports" | while read -r line; do
            echo "$line - $(sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$line" ps aux 2>/dev/null | grep pts | awk '{print $11}' | tr '\n' ' ')";
          done | fzf | awk '{print $1}')

          if [[ -z "$target" ]]; then
            echo "Cancelled."
            exit 1
          fi

          sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$target"
        '';
      })
    ];
  };
}
