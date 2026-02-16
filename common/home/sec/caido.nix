{ pkgs, lib, config, ... }:

{
  options.sprrw.sec.caido = {
    enable = lib.mkEnableOption "caido";
  };

  config = let
    cfg = config.sprrw.sec.caido;
  in lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "caido";
        text = ''
        if docker inspect caido &>/dev/null; then
          echo "Caido already running!"
          exit 1
        fi

        mkdir -p ~/.local/share/caido-docker
        chmod 777 ~/.local/share/caido-docker
        docker run --rm -d -p 8080:8080 --name caido -v "$HOME/.local/share/caido-docker:/home/caido/.local/share/caido" caido/caido caido-cli --allow-guests --no-renderer-sandbox --listen 0.0.0.0:8080
        '';
      })
      (pkgs.writeShellApplication {
        name = "caido-stop";
        text = ''
        docker stop caido
        '';
      })
      (pkgs.writeShellApplication {
        name = "caido-update";
        text = ''
        docker pull caido/caido
        '';
      })
    ];
  };
}
