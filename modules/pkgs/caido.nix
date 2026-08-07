{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        caido = pkgs.writeShellApplication {
          name = "caido";
          text = ''
            if podman ps --format "{{.Names}}" | grep -q "^caido$"; then
              echo "Caido already running!"
              exit 1
            fi

            mkdir -p ~/.local/share/caido-docker
            chmod 777 ~/.local/share/caido-docker
            podman run --userns=keep-id --rm --network host -d --name caido -v "$HOME/.local/share/caido-docker:/home/caido/.local/share/caido" caido/caido caido-cli --allow-guests --no-renderer-sandbox --listen 0.0.0.0:8080
          '';
        };
      };
    };
}
