{
  perSystem =
    {
      pkgs,
      pkgs-unstable,
      lib,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        pi-boxed =
          let
            pi-boxed = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
          in
          pkgs.writeShellApplication {
            name = "pi";
            # TODO: Cross platform fallback for path
            text = ''
              SPRRW_PATH="$(readlink /etc/static/hm-package)/home-path/bin:$(readlink /run/current-system/sw)/bin" ${pi-boxed}/bin/pi ${pkgs-unstable.pi-coding-agent}/bin/pi "$@"
            '';
          };
      };
    };
}
