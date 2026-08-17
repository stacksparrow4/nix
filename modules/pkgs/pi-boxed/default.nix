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
            text = ''
              ${pi-boxed}/bin/pi ${pkgs-unstable.pi-coding-agent}/bin/pi "$@"
            '';
          };
      };
    };
}
