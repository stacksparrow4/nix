{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw = {
    sandbox = {
      enable = lib.mkEnableOption "sandboxing";

      create = lib.mkOption {
        type = lib.types.functionTo lib.types.package;
      };
    };

    sandboxing = {
      runDocker = lib.mkOption { };
      runDockerBin = lib.mkOption { };
      recipes = lib.mkOption { };
      runVM = lib.mkOption { };
    };
  };

  config = {
    sprrw.sandbox.create =
      {
        name,
        type ? "bwrap", # bwrap, docker/podman, vm
        outsideBeforeScript ? "",
        prog, # path to the program. Will be called with forwarded arguments
        shareCwd ? false,
        sharedPaths ? [ ], # { hostPath, boxPath, ro ? false, type = "dir"|"file", needsCreate ? true }. Can contain shell characters such as $() but will be wrapped in double quotes
        envVars ? [ ],
        downgradeTerm ? false, # sets term to xterm-256color for tools that don't support terminfo
        stdin ? true,
        tty ? true,
        network ? false,
        hostNetwork ? false,
        wayland ? false,
        x11 ? false,
      }:
      let
        dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
          FROM alpine@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

          RUN adduser -s ${pkgs.bash}/bin/bash -G users -D sprrw
        '';
        dockerInit =
          execMode:
          pkgs.writeShellScript "dockerinit" ''
            set -e

            ${
              if execMode then
                ""
              else
                ''
                  cp -r /etc/hm-package/home-files/.* ~/
                  chmod -R u+w ~/.* &>/dev/null || true
                ''
            }

            exec "$@"
          '';
        allSharedPaths =
          map
            (
              x:
              # Apply defaults
              {
                ro = false;
                needsCreate = true;
              }
              // x
            )
            (
              sharedPaths
              ++ (
                if shareCwd then
                  [
                    {
                      hostPath = "$(pwd)";
                      boxPath = "/pwd";
                      ro = false;
                      type = "dir";
                      needsCreate = false;
                    }
                  ]
                else
                  [ ]
              )
              ++ [
                {
                  hostPath = "/nix/store";
                  boxPath = "/nix/store";
                  ro = true;
                  type = "dir";
                  needsCreate = false;
                }
                {
                  hostPath = "/bin";
                  boxPath = "/bin";
                  ro = true;
                  type = "dir";
                  needsCreate = false;
                }
                {
                  hostPath = "/etc";
                  boxPath = "/etc";
                  ro = true;
                  type = "dir";
                  needsCreate = false;
                }
                {
                  hostPath = "/usr";
                  boxPath = "/usr";
                  ro = true;
                  type = "dir";
                  needsCreate = false;
                }
                {
                  hostPath = "/run/current-system/sw";
                  boxPath = "/run/current-system/sw";
                  ro = true;
                  type = "dir";
                  needsCreate = false;
                }
                {
                  hostPath = "/home/sprrw/nixos";
                  boxPath = "/home/sprrw/nixos";
                  ro = true;
                  type = "dir";
                  needsCreate = false;
                }
              ]
              ++ (
                if wayland then
                  [
                    {
                      hostPath = "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY";
                      boxPath = "/tmp/$WAYLAND_DISPLAY";
                      ro = true;
                      type = "file";
                      needsCreate = false;
                    }
                  ]
                else
                  [ ]
              )
              ++ (
                if x11 then
                  [
                    {
                      hostPath = "/tmp/.X11-unix";
                      boxPath = "/tmp/.X11-unix";
                      ro = true;
                      type = "file";
                      needsCreate = false;
                    }
                  ]
                else
                  [ ]
              )
            );
        allEnvVars =
          envVars
          ++ [
            "PATH=/etc/hm-package/home-path/bin:/run/current-system/sw/bin"
            "HOME=/home/sprrw"
          ]
          ++ (if downgradeTerm then [ "TERM=xterm-256color" ] else [ "TERM=\"$TERM\"" ])
          ++ (
            if wayland then
              [
                "WAYLAND_DISPLAY=\"$WAYLAND_DISPLAY\""
                "XDG_RUNTIME_DIR=/tmp"
              ]
            else
              [ ]
          )
          ++ (if x11 then [ "DISPLAY=\"$DISPLAY\"" ] else [ ]);
        backslashify =
          arr:
          if (builtins.length arr) == 0 then
            "\\"
          else
            builtins.concatStringsSep "\n  " (map (x: "${x} \\") arr);
        # TODO: check that there are no unix sockets in any of the shares
        finalCmd =
          if type == "bwrap" then
            ''
              env -i ${pkgs.bubblewrap}/bin/bwrap \
                --unshare-all \
                --as-pid-1 \
                --tmpfs /tmp \
                --proc /proc \
                --dev /dev \
                --dir /home/sprrw \
                ${if network then "--share-net" else ""} \
                ${if shareCwd then "--chdir /pwd" else "--chdir /home/sprrw"} \
                ${backslashify (
                  map (
                    {
                      hostPath,
                      boxPath,
                      ro,
                      ...
                    }:
                    "--${if ro then "ro-" else ""}bind \"${hostPath}\" \"${boxPath}\""
                  ) allSharedPaths
                )}
                /usr/bin/env ${builtins.concatStringsSep " " allEnvVars} \
                ${prog} "$@"
            ''
          else if type == "docker" || type == "podman" then
            ''
              if ! podman image inspect usermapped-img &>/dev/null; then
                podman build -t usermapped-img ${dockerFileDir}
              fi
              podman run \
                --userns=keep-id \
                --hostname sandbox \
                -u 1000:100 \
                --rm \
                ${if stdin then "-i" else ""} ${if tty then "-t" else ""} \
                ${if !network then "--network none" else ""} \
                ${if hostNetwork then "--network host" else ""} \
                ${if shareCwd then "-w /pwd" else "-w /home/sprrw"} \
                ${backslashify (map (e: "-e ${e}") allEnvVars)}
                ${backslashify (
                  map (
                    {
                      hostPath,
                      boxPath,
                      ro,
                      ...
                    }:
                    "-v \"${hostPath}\":\"${boxPath}\"${if ro then ":ro" else ""}"
                  ) allSharedPaths
                )}
                usermapped-img \
                ${dockerInit false} \
                ${prog} "$@"
            ''
          else
            assert type == "vm";
            ''
              echo TODO
            '';
      in
      assert !hostNetwork || network; # Can't have hostNetwork = true and network = false
      pkgs.writeShellApplication {
        inherit name;
        text = ''
          # TODO: write some check for already inside sandbox. Possible checking /.sprrw-sandbox file

          ${outsideBeforeScript}

          # Create shared folders if they dont exist
          ${builtins.concatStringsSep "\n" (
            map
              (
                { hostPath, type, ... }:
                if type == "dir" then
                  ''
                    if ! [[ -d "${hostPath}" ]]; then
                      mkdir -p "${hostPath}"
                    fi
                  ''
                else
                  assert type == "file";
                  ''
                    if ! [[ -f "${hostPath}" ]]; then
                      mkdir -p "$(dirname "${hostPath}")"
                      touch "${hostPath}"
                    fi
                  ''
              )
              (
                builtins.filter (
                  {
                    needsCreate,
                    ...
                  }:
                  needsCreate
                ) allSharedPaths
              )
          )}

          ${finalCmd}
        '';
      };

    sprrw.sandboxing.runDocker = lib.warn "runDocker used" (
      pkgs.writeShellApplication {
        name = "tmp";
        text = ''
          echo TODO
        '';
      }
    );

    sprrw.sandboxing.runDockerBin =
      _:
      lib.warn "runDockerBin used" (
        pkgs.writeShellApplication {
          name = "tmp";
          text = ''
            echo TODO
          '';
        }
      );

    sprrw.sandboxing.recipes = lib.warn "recipes used" {
      pwd_starter = "TODO";
    };

    sprrw.sandboxing.runVM =
      _:
      lib.warn "runVM used" (
        pkgs.writeShellApplication {
          name = "tmp";
          text = ''
            echo TODO
          '';
        }
      );

    #       sprrw.sandboxing.runVM =
    #         {
    #           qemu_args ? "",
    #           script ? "bash",
    #         }:
    #         (pkgs.writeShellScript "vm" ''
    #           open_port=$(comm -23 <(seq 49152 65535) <(ss -tan | awk '{print $4}' | cut -d':' -f2 | grep "[0-9]\{1,5\}" | sort | uniq) | shuf | head -n 1) || true
    #           echo "Forwarding SSH to port $open_port"
    #           pidfile=$(mktemp)
    #           qemu-system-x86_64 -enable-kvm -m 16384 -smp 4 -cdrom ~/.local/vm.iso -boot d -nic user,hostfwd=tcp:127.0.0.1:"$open_port"-:22 -display none -daemonize -pidfile "$pidfile" ${qemu_args}
    #           qemupid=$(cat "$pidfile")
    #           rm "$pidfile"
    #           echo "Process id $qemupid"
    #
    #           sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$open_port" bash -c 'cat > /tmp/startup.sh' <<"BIGEOFTHATWONTDUP" || true
    #           ${script}
    #           BIGEOFTHATWONTDUP
    #
    #           sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$open_port" -t bash /tmp/startup.sh "$@" || true
    #
    #           echo "Terminating qemu..."
    #           kill "$qemupid"
    #
    #           echo "Done!"
    #         '');
    #
    #       sprrw.sandboxing.runVMBin =
    #         {
    #           name,
    #           qemu_args ? "",
    #           script ? "bash",
    #         }:
    #         pkgs.writeShellApplication {
    #           inherit name;
    #           text = ''
    #             ${cfg.runVM { inherit qemu_args script; }} "$@"
    #           '';
    #         };

    home.packages =
      (builtins.concatMap
        (
          type:
          (
            let
              create =
                args:
                config.sprrw.sandbox.create (
                  {
                    inherit type;
                    network = true;
                    stdin = true;
                    tty = true;
                    prog = "${pkgs.bash}/bin/bash";
                  }
                  // args
                  // {
                    name = if type == "bwrap" then args.name else "${args.name}-${type}";
                  }
                );
            in
            [
              (create { name = "box"; })
              (create {
                name = "box-cwd";
                shareCwd = true;
              })
              (create {
                name = "box-gui";
                wayland = true;
                x11 = true;
              })
              (create {
                name = "box-gui-cwd";
                shareCwd = true;
                wayland = true;
                x11 = true;
              })
            ]
          )
        )
        [
          "bwrap"
          "podman"
          "docker"
          "vm"
        ]
      )
      ++ [
        (pkgs.writeShellApplication {
          name = "box-enter";
          text = ''
            targets=$(podman ps --format json | jq -r '.[] | select(.Image == "localhost/usermapped-img:latest") | .Id')

            if [[ -z "$targets" ]]; then
              echo "No valid sandboxes found"
              exit 1
            fi

            target=$(echo "$targets" | while read -r containerid; do
              echo "''${containerid:0:10} - $(podman exec "$containerid" ps aux | tail -n +2 | head -n -1 | awk '{print $11}' | awk -F/ '{print $NF}' | tr '\n' ' ')";
            done | fzf | awk '{print $1}')

            if [[ -z "$target" ]]; then
              echo "Cancelled."
              exit 1
            fi

            podman exec -it "$target" bash
          '';
        })

        (pkgs.writeShellApplication {
          name = "build-vm";
          text = ''
            cd ~/${config.sprrw.nixosRepoPath}
            git add .

            isopath=$(nixos-rebuild build-image --flake .#sandbox --image-variant iso --no-link)
            echo "$isopath"

            mkdir -p ~/.local

            rm -f ~/.local/vm.iso
            ln -s "$isopath" ~/.local/vm.iso
          '';
        })
        #         (cfg.runVMBin {
        #           name = "vm";
        #         })
        #         (cfg.runVMBin {
        #           name = "vm-cwd";
        #           qemu_args = "-virtfs local,path=$(pwd),mount_tag=pwdshare,security_model=none,id=host1";
        #           script = ''
        #             sudo mkdir -p /mnt/pwd
        #             sudo mount -t 9p -o trans=virtio,version=9p2000.L pwdshare /mnt/pwd
        #             cd /mnt/pwd
        #             bash
        #           '';
        #         })
        #         (pkgs.writeShellApplication {
        #           name = "vm-enter";
        #           text = ''
        #             ports=$(ss -tlpn | grep qemu-system | grep -oE '127\.0\.0\.1:[0-9]+' | cut -d: -f2)
        #
        #             if [[ -z "$ports" ]]; then
        #               echo "No valid vms found"
        #               exit 1
        #             fi
        #
        #             target=$(echo "$ports" | while read -r line; do
        #               echo "$line - $(sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$line" ps aux 2>/dev/null | grep pts | awk '{print $11}' | tr '\n' ' ')";
        #             done | fzf | awk '{print $1}')
        #
        #             if [[ -z "$target" ]]; then
        #               echo "Cancelled."
        #               exit 1
        #             fi
        #
        #             sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$target"
        #           '';
        #         })
      ];
  };
}
