{ lib, config, ... }@inputs:

{
  options = {
    sprrw.sec.windows.responder-docker.enable = lib.mkEnableOption "responder-docker";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.system; };
  in lib.mkIf config.sprrw.sec.windows.responder-docker.enable {
    home.packages = [(
      let
        responderDocker = pkgs.dockerTools.buildImage {
          name = "responder-docker";
          tag = "latest";
          config = {
            Cmd = [ "${pkgs.responder}/bin/responder" "-I" "eth0" ];
            Env = [
              "PYTHONUNBUFFERED=1"
            ];
          };
          copyToRoot = with pkgs; [
            coreutils
            iproute2
          ];
        };
        forwardToResponder = pkgs.writeShellScript "forward-to-responder" ''
          echo "Forwarding $1 to responder..."

          sudo socat -dd TCP4-LISTEN:$1,fork,reuseaddr TCP:$(docker inspect responder-docker | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'):$1
        '';
      in
        pkgs.writeShellScriptBin "responder-docker" ''
          if ! docker image inspect responder-docker:latest &>/dev/null; then
            docker load < ${responderDocker}
          fi
          docker run --rm --name responder-docker responder-docker &
          sleep 1
          ${pkgs.parallel}/bin/parallel ::: '${forwardToResponder} 135' '${forwardToResponder} 3389' '${forwardToResponder} 389' '${forwardToResponder} 445' '${forwardToResponder} 21' '${forwardToResponder} 25' '${forwardToResponder} 53' '${forwardToResponder} 80' '${forwardToResponder} 88' '${forwardToResponder} 110' '${forwardToResponder} 139' '${forwardToResponder} 143' '${forwardToResponder} 587' '${forwardToResponder} 1433' '${forwardToResponder} 1883' '${forwardToResponder} 5985' '${forwardToResponder} 49602'
          docker kill responder-docker
        ''
    )];
  };
}
