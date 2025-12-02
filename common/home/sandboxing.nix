{ pkgs, lib, config, ... }:

{
  options.sprrw.sandboxing = {
    enable = lib.mkEnableOption "sandboxing";

    runDocker = lib.mkOption {
      type = lib.types.anything;
    };

    homeConfig = lib.mkOption {
      type = lib.types.anything;
    };
  };

  config = let
    cfg = config.sprrw.sandboxing;
    runDocker = {
      cmd,
      shareCwd ? false,
      shareX11 ? false,
      netHost ? false,
    }:
    let
      dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
        FROM alpine@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

        RUN adduser -s ${pkgs.bash}/bin/bash -G users -D sprrw
      '';
      dockerinit = import ../../hosts/docker/dockerinit.nix {
        inherit pkgs;

        homeConfig = cfg.homeConfig;
      };
    in
    pkgs.writeShellScript "sandboxed-${cmd}" ''
      if ! docker inspect usermapped-img &>/dev/null; then
        docker build -t usermapped-img ${dockerFileDir}
      fi

      docker run \
        -u 1000:100 \
        --rm -it \
        -v /nix:/nix:ro \
        -v /etc/fonts:/etc/fonts:ro \
        ${if shareCwd then "-v $(pwd):/pwd" else ""} \
        ${if shareX11 then "-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/home/sprrw/.Xauthority" else ""} \
        ${if netHost then "--network host" else ""} \
        ${if shareCwd then "-w /pwd" else "-w /home/sprrw"} \
        usermapped-img ${dockerinit} ${cmd} "$@"
    '';
  in lib.mkIf cfg.enable {
    sprrw.nvim.sandboxed = true;
    sprrw.gui.brave.sandboxed = false; # TODO: get around setuid sandbox issue

    sprrw.sandboxing.runDocker = runDocker;

    home.packages = [
      (
        pkgs.runCommand "box" {} ''
          mkdir -p $out/bin
          ln -s ${runDocker { cmd = "bash"; }} $out/bin/box
          ln -s ${runDocker { cmd = "bash"; shareCwd = true; }} $out/bin/box-cwd
          ln -s ${runDocker { cmd = "bash"; shareX11 = true; netHost = true; }} $out/bin/box-gui
          ln -s ${runDocker { cmd = "bash"; shareCwd = true; shareX11 = true; netHost = true; }} $out/bin/box-cwd-gui
        ''
      )
    ];
  };
}
