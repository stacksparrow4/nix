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
      shareCwd ? false
    }:
    let
      dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
        FROM ubuntu@sha256:66460d557b25769b102175144d538d88219c077c678a49af4afca6fbfc1b5252

        # Change ubuntu to id 1000 gid 100 and shell bash
        RUN usermod -g users ubuntu && chsh -s "${pkgs.bash}/bin/bash" ubuntu
      '';
      shareCwdArg = if shareCwd then "-v $(pwd):/pwd" else "";
      dockerinit = import ../../hosts/docker/dockerinit.nix {
        inherit pkgs inputs cmd;
        cwd = "/pwd";
      };
    in
    pkgs.writeShellScript "sandboxed-${cmd}" ''
      if ! docker inspect usermapped-img &>/dev/null; then
        docker build -t usermapped-img ${dockerFileDir}
      fi

      docker run -u 1000:100 --rm -it -v /nix:/nix:ro ${shareCwdArg} usermapped-img ${dockerinit}
    '';
  };
}
