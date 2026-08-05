{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        noctalia-reset = pkgs.writeShellApplication {
          name = "noctalia-reset";
          text = ''
            rm -f ~/.local/state/noctalia/settings.toml
            kill "$(pidof noctalia)" || true
            nohup noctalia &>/dev/null &
          '';
        };
      };
    };
}
