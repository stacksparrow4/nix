{ pkgs, lib, config, ... }:

{
  options.sprrw.sandboxing = {
    enable = lib.mkEnableOption "sandboxing";

    additionalDockerArgs = lib.mkOption {
      default = "";
    };

    runDocker = lib.mkOption {};
    runDockerBin = lib.mkOption {};
  };

  config = let
    cfg = config.sprrw.sandboxing;
  in lib.mkIf cfg.enable {
    sprrw.sandboxing.runDocker = {
      cmd,
      shareCwd ? false,
      shareX11 ? false,
      netHost ? false,
      shouldExec ? false,
      stdin ? true,
      tty ? true,
      disableWorkdir ? false,
      additionalRuntimeArgs ? 0,
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

        ${if shouldExec then "" else "cp -r /etc/hm-package/home-files/.* ~/"}
        ${if shouldExec then "" else "chmod -R u+w ~/.* &>/dev/null || true"}

        export PATH="/etc/hm-package/home-path/bin:$PATH"

        exec "$@"
      '';
    in
    pkgs.writeShellScript "sandboxed-${cmd}" ''
      if ! docker inspect usermapped-img &>/dev/null; then
        docker build -t usermapped-img ${dockerFileDir}
      fi

      docker ${if shouldExec then "exec" else "run"} \
        ${if stdin then "-i" else ""} \
        ${if tty then "-t" else ""} \
        ${if shouldExec then "" else ''\
        --rm \
        --hostname sandbox \
        -v /nix:/nix:ro -v /etc/fonts:/etc/fonts:ro -v /etc/hm-package:/etc/hm-package:ro -v ${config.home.homeDirectory}/nixos:/home/sprrw/nixos:ro \
        -u 1000:100 \
        -e TERM \
        ${cfg.additionalDockerArgs} \
        ${if additionalRuntimeArgs > 0 then "\"$_ADDITIONAL_DOCKER_ARG_1\"" else "" } \
        ${if additionalRuntimeArgs > 1 then "\"$_ADDITIONAL_DOCKER_ARG_2\"" else "" } \
        ${if additionalRuntimeArgs > 2 then "\"$_ADDITIONAL_DOCKER_ARG_3\"" else "" } \
        ${if additionalRuntimeArgs > 3 then "\"$_ADDITIONAL_DOCKER_ARG_4\"" else "" } \
        ${if shareX11 then "-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/home/sprrw/.Xauthority" else ""} \
        ${if netHost then "--network host" else ""} \
        ${if shareCwd then "-w /pwd -v $(pwd):/pwd" else (if disableWorkdir then "" else "-w /home/sprrw")}''} \
        ${if shouldExec then "$(docker ps --format json | jq -r 'select(.Image == \"usermapped-img\") | .ID' | while read dockerid; do echo \"$dockerid - $(docker exec \"$dockerid\" ps | tail -n +2 | head -n -1 | awk '{print $4}' | awk -F/ '{print $NF}' | tr '\\n' ' ')\"; done | fzf | awk '{print $1}')" else "usermapped-img"} ${dockerInit} ${cmd} "$@"
    '';

    sprrw.sandboxing.runDockerBin = { binName, ... }@args: pkgs.runCommand binName {} ''
      mkdir -p $out/bin
      ln -s ${cfg.runDocker (removeAttrs args [ "binName" ])} $out/bin/${binName}
    '';

    home.packages = [
      (cfg.runDockerBin { binName = "box"; cmd = "bash"; })
      (cfg.runDockerBin { binName = "box-cwd"; cmd = "bash"; shareCwd = true; })
      (cfg.runDockerBin { binName = "box-gui"; cmd = "bash"; shareX11 = true; netHost = true; })
      (cfg.runDockerBin { binName = "box-cwd-gui"; cmd = "bash"; shareCwd = true; shareX11 = true; netHost = true; })
      (cfg.runDockerBin { binName = "box-enter"; cmd = "bash"; shouldExec = true; })
    ];

    home.file.".xprofile".text = ''
      ${pkgs.xorg.xhost}/bin/xhost +local:docker/sandbox
    '';
  };
}
