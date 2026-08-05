# Sandboxed wrappers for the mobile / reversing / cracking tooling, plus caido.
{
  perSystem =
    {
      pkgs,
      lib,
      config,
      mkSandbox,
      ...
    }:
    let
      cwdOnly =
        name: prog:
        mkSandbox {
          inherit name prog;
          shareCwd = true;
        };
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        # mobile
        apktool = cwdOnly "apktool" "${pkgs.apktool}/bin/apktool";
        jadx = cwdOnly "jadx" "${pkgs.jadx}/bin/jadx";

        # reversing
        webcrack-boxed = cwdOnly "webcrack" "${config.packages.webcrack}/bin/webcrack";

        # cracking
        hydra = mkSandbox {
          name = "hydra";
          shareCwd = true;
          network = true;
          prog = "${pkgs.thc-hydra}/bin/hydra";
        };

        # Caido runs as a podman container; this only drives it.
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
