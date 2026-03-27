{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.sandboxing = {
    enable = lib.mkEnableOption "sandboxing";

    runDocker = lib.mkOption { };
    runDockerBin = lib.mkOption { };

    runVM = lib.mkOption { };
    runVMBin = lib.mkOption { };

    recipes = lib.mkOption { };
  };

  config =
    let
      cfg = config.sprrw.sandboxing;
      dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
        FROM alpine@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

        RUN adduser -s ${pkgs.bash}/bin/bash -G users -D sprrw && \
          apk add sudo && \
          echo 'sprrw ALL=(ALL:ALL) NOPASSWD:SETENV: ALL' > /etc/sudoers && \
          mkdir -p /home/sprrw/.config /home/sprrw/.local/share /home/sprrw/.cache && chown -R sprrw: /home/sprrw
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

          export PATH="/etc/hm-package/home-path/bin:$PATH"

          exec "$@"
        '';
      isMac = lib.strings.hasSuffix "-darwin" pkgs.stdenv.hostPlatform.system;
    in
    {
      sprrw.sandboxing.runDocker =
        if cfg.enable then
          (
            if isMac then
              pkgs.writeShellScript "run-docker" ''
                echo "Sandbox not supported on Mac"
                exit 1
              ''
            else
              pkgs.writeShellScript "run-docker" ''
                if ! docker inspect usermapped-img &>/dev/null; then
                  docker build -t usermapped-img ${dockerFileDir}
                fi

                ${pkgs.python3}/bin/python ${./start-sandbox.py} ${dockerInit false} "$@"
              ''
          )
        else
          (pkgs.writeShellScript "run-docker-stub" ''
            found=false
            cmd=()

            for arg in "$@"; do
              if $found; then
                cmd+=("$arg")
              elif [[ "$arg" == "DOCKERIMG" ]]; then
                found=true
              fi
            done

            if $found && [[ ''${#cmd[@]} -gt 0 ]]; then
              "''${cmd[@]}"
            else
              echo "Invalid run-docker command without sandbox" >&2
              exit 1
            fi
          '');

      sprrw.sandboxing.runDockerBin =
        { name, args }:
        (pkgs.writeShellApplication {
          inherit name;
          # Duplicated isMac code so that we can hopefully avoid building some packages
          text =
            if isMac then
              ''
                echo "Sandbox not supported on Mac"
                exit 1
              ''
            else
              ''
                ${cfg.runDocker} ${args} "$@"
              '';
        });

      sprrw.sandboxing.recipes =
        let
          dir_as_pwd_starter = dir: "-it -w /pwd -v \"${dir}\":/pwd";
        in
        {
          home_dir_starter = "-it -w /home/sprrw";
          inherit dir_as_pwd_starter;
          pwd_starter = dir_as_pwd_starter "$(pwd)";
          gui = "-e WAYLAND_DISPLAY=\"$WAYLAND_DISPLAY\" -v \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY\" -e XDG_RUNTIME_DIR=/tmp -e DISPLAY=\"$DISPLAY\" -v /tmp/.X11-unix:/tmp/.X11-unix";
          gpu = "--device=nvidia.com/gpu=all";
        };

      sprrw.sandboxing.runVM =
        {
          qemu_args ? "",
          script ? "bash",
        }:
        (pkgs.writeShellScript "vm" ''
          open_port=$(comm -23 <(seq 49152 65535) <(ss -tan | awk '{print $4}' | cut -d':' -f2 | grep "[0-9]\{1,5\}" | sort | uniq) | shuf | head -n 1) || true
          echo "Forwarding SSH to port $open_port"
          pidfile=$(mktemp)
          qemu-system-x86_64 -enable-kvm -m 16384 -smp 4 -cdrom ~/.local/vm.iso -boot d -nic user,hostfwd=tcp:127.0.0.1:"$open_port"-:22 -display none -daemonize -pidfile "$pidfile" ${qemu_args}
          qemupid=$(cat "$pidfile")
          rm "$pidfile"
          echo "Process id $qemupid"

          sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$open_port" bash -c 'cat > /tmp/startup.sh' <<"BIGEOFTHATWONTDUP" || true
          ${script}
          BIGEOFTHATWONTDUP

          sshpass -p password ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password localhost -p "$open_port" -t bash /tmp/startup.sh "$@" || true

          echo "Terminating qemu..."
          kill "$qemupid"

          echo "Done!"
        '');

      sprrw.sandboxing.runVMBin =
        {
          name,
          qemu_args ? "",
          script ? "bash",
        }:
        pkgs.writeShellApplication {
          inherit name;
          text = ''
            ${cfg.runVM { inherit qemu_args script; }} "$@"
          '';
        };

      home.packages = [
        (cfg.runDockerBin {
          name = "box";
          args = "${cfg.recipes.home_dir_starter} DOCKERIMG bash";
        })
        (cfg.runDockerBin {
          name = "box-cwd";
          args = "${cfg.recipes.pwd_starter} DOCKERIMG bash";
        })
        (cfg.runDockerBin {
          name = "box-gui";
          args = "${cfg.recipes.home_dir_starter} ${cfg.recipes.gui} DOCKERIMG bash";
        })
        (cfg.runDockerBin {
          name = "box-gui-cwd";
          args = "${cfg.recipes.pwd_starter} ${cfg.recipes.gui} DOCKERIMG bash";
        })
        (cfg.runDockerBin {
          name = "box-gui-gpu";
          args = "${cfg.recipes.home_dir_starter} ${cfg.recipes.gui} ${cfg.recipes.gpu} DOCKERIMG bash";
        })
        (cfg.runDockerBin {
          name = "box-gui-gpu-cwd";
          args = "${cfg.recipes.pwd_starter} ${cfg.recipes.gui} ${cfg.recipes.gpu} DOCKERIMG bash";
        })

        (pkgs.writeShellApplication {
          name = "box-enter";
          text = ''
            targets=$(docker ps --format json | jq -r 'select(.Image == "usermapped-img") | .ID')

            if [[ -z "$targets" ]]; then
              echo "No valid sandboxes found"
              exit 1
            fi

            target=$(echo "$targets" | while read -r dockerid; do
              echo "$dockerid - $(docker exec "$dockerid" ps | tail -n +2 | head -n -1 | awk '{print $4}' | awk -F/ '{print $NF}' | tr '\n' ' ')";
            done | fzf | awk '{print $1}')

            if [[ -z "$target" ]]; then
              echo "Cancelled."
              exit 1
            fi

            docker exec -it "$target" "${dockerInit true}" bash
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

            ln -s "$isopath" ~/.local/vm.iso
          '';
        })
        (cfg.runVMBin {
          name = "vm";
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
