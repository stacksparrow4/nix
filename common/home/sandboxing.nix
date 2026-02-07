{ pkgs, lib, config, ... }:

{
  options.sprrw.sandboxing = {
    # Sandboxing code is always loaded but apps can use this switch to follow an "unsandboxed path" vs a "sandboxed path"
    enable = lib.mkEnableOption "sandboxing";

    runDocker = lib.mkOption {};
    runDockerBin = lib.mkOption {};
  };

  config = let
    cfg = config.sprrw.sandboxing;
  in {
    sprrw.sandboxing.runDocker = {
      shouldExec ? false,
      beforeTargetArgs ? "",
      afterTargetArgs,
    }:
    let
      dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
        FROM alpine@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

        RUN adduser -s ${pkgs.bash}/bin/bash -G users -D sprrw && \
          apk add sudo && \
          echo 'sprrw ALL=(ALL:ALL) NOPASSWD:SETENV: ALL' > /etc/sudoers
      '';
      dockerInit = pkgs.writeShellScript "dockerinit" ''
        set -e

        ${if shouldExec then "" else ''
        cp -r /etc/hm-package/home-files/.* ~/
        chmod -R u+w ~/.* &>/dev/null || true
        ''}

        export PATH="/etc/hm-package/home-path/bin:$PATH"

        exec "$@"
      '';
    in
    pkgs.writeShellScript "sandbox-wrapper" (''
      if ! docker inspect usermapped-img &>/dev/null; then
        docker build -t usermapped-img ${dockerFileDir}
      fi
    '' + (if shouldExec then ''
      targets=$(docker ps --format json | jq -r 'select(.Image == "usermapped-img") | .ID')

      if [[ -z "$targets" ]]; then
        echo "No valid sandboxes found"
        exit 1
      fi

      target=$(echo "$targets" | while read dockerid; do
        echo "$dockerid - $(docker exec "$dockerid" ps | tail -n +2 | head -n -1 | awk '{print $4}' | awk -F/ '{print $NF}' | tr '\n' ' ')";
      done | fzf | awk '{print $1}')

      if [[ -z "$target" ]]; then
        echo "Cancelled."
        exit 1
      fi

      docker exec ${beforeTargetArgs} "$target" "${dockerInit}" ${afterTargetArgs} "$@"
    '' else ''
      docker run --rm --hostname sandbox \
        -v /nix:/nix:ro -v /etc/fonts:/etc/fonts:ro -v /etc/hm-package:/etc/hm-package:ro \
        -v ${config.home.homeDirectory}/nixos:/home/sprrw/nixos:ro \
        -u 1000:100 -e TERM \
        ${beforeTargetArgs} usermapped-img "${dockerInit}" ${afterTargetArgs} "$@"
    ''));

    sprrw.sandboxing.runDockerBin = { binName, ... }@args: (pkgs.runCommand binName {} ''
      mkdir -p $out/bin
      ln -s "${cfg.runDocker (removeAttrs args [ "binName" ])}" "$out/bin/${binName}"
    '');

    home.packages = [
      (cfg.runDockerBin { binName = "box"; beforeTargetArgs = "-it -w /home/sprrw"; afterTargetArgs = "bash"; })
      (cfg.runDockerBin { binName = "box-cwd"; beforeTargetArgs = "-it -w /pwd -v $(pwd):/pwd"; afterTargetArgs = "bash"; })
      (cfg.runDockerBin {
        binName = "box-gui";
        beforeTargetArgs = "-it -w /home/sprrw -e DISPLAY "
          + "-v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/home/sprrw/.Xauthority "
          + "--network host";
        afterTargetArgs = "bash";
      })
      (cfg.runDockerBin {
        binName = "box-cwd-gui";
        beforeTargetArgs = "-it -w /pwd -v $(pwd):/pwd -e DISPLAY "
          + "-v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/home/sprrw/.Xauthority "
          + "--network host";
        afterTargetArgs = "bash";
      })
      (cfg.runDockerBin { binName = "box-enter"; shouldExec = true; beforeTargetArgs = "-it"; afterTargetArgs = "bash"; })
    ];

    home.file.".xprofile".text = lib.mkIf cfg.enable ''
      ${pkgs.xorg.xhost}/bin/xhost +local:docker/sandbox
    '';
  };
}
