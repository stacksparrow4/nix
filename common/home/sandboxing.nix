{ pkgs, lib, config, inputs, ... }:

{
  options.sprrw.sandboxing = {
    enable = lib.mkEnableOption "sandboxing";

    runDocker = lib.mkOption {
      type = lib.types.anything;
    };
  };

  config = lib.mkIf config.sprrw.sandboxing.enable {
    sprrw.nvim.sandboxed = true;

    sprrw.sandboxing.runDocker = {
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
      shareCwdArg = if shareCwd then "-v $(pwd):/pwd" else "";
      shareX11Arg = if shareX11 then "-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/home/sprrw/.Xauthority" else "";
      netHostArg = if netHost then "--network host" else "";
      dockerinit = import ../../hosts/docker/dockerinit.nix {
        inherit pkgs inputs cmd;
        cwd = "/pwd";
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
        ${shareCwdArg} \
        ${shareX11Arg} \
        ${netHostArg} \
        usermapped-img ${dockerinit} "$@"
    '';
  };
}
