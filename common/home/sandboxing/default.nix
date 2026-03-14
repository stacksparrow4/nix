{ pkgs, lib, config, ... }:

{
  options.sprrw.sandboxing = {
    runDocker = lib.mkOption {};
    runDockerBin = lib.mkOption {};

    recipes = lib.mkOption {};
  };

  config = let
    cfg = config.sprrw.sandboxing;
    dockerFileDir = pkgs.writeTextDir "Dockerfile" ''
      FROM alpine@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

      RUN adduser -s ${pkgs.bash}/bin/bash -G users -D sprrw && \
        apk add sudo && \
        echo 'sprrw ALL=(ALL:ALL) NOPASSWD:SETENV: ALL' > /etc/sudoers
    '';
    dockerInit = execMode: pkgs.writeShellScript "dockerinit" ''
      set -e

      ${if execMode then "" else ''
      cp -r /etc/hm-package/home-files/.* ~/
      chmod -R u+w ~/.* &>/dev/null || true
      ''}

      export PATH="/etc/hm-package/home-path/bin:$PATH"

      exec "$@"
    '';
  in {
    sprrw.sandboxing.runDocker = pkgs.writeShellScript "run-docker" ''
      if ! docker inspect usermapped-img &>/dev/null; then
        docker build -t usermapped-img ${dockerFileDir}
      fi

      ${pkgs.python3}/bin/python ${./start-sandbox.py} ${dockerInit false} "$@"
    '';

    sprrw.sandboxing.runDockerBin = { name, args }: (pkgs.writeShellApplication {
      inherit name;
      text = ''
        ${cfg.runDocker} ${args} "$@"
      '';
    });

    sprrw.sandboxing.recipes = let
      dir_as_pwd_starter = dir: "-it -w /pwd -v \"${dir}\":/pwd";
    in {
      home_dir_starter = "-it -w /home/sprrw";
      inherit dir_as_pwd_starter;
      pwd_starter = dir_as_pwd_starter "$(pwd)";
    };

    home.packages = [
      (cfg.runDockerBin { name = "box"; args = "${cfg.recipes.home_dir_starter} DOCKERIMG bash"; })
      (cfg.runDockerBin { name = "box-cwd"; args = "${cfg.recipes.pwd_starter} DOCKERIMG bash"; })

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
    ];
  };
}
