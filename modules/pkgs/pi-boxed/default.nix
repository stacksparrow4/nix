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
              export SPRRW_PATH
              if [[ -d /etc/static/hm-package ]] && [[ -d /run/current-system/sw ]]; then
                SPRRW_PATH="$(readlink /etc/static/hm-package)/home-path/bin:$(readlink /run/current-system/sw)/bin"
              fi
              ${pi-boxed}/bin/pi ${pkgs-unstable.pi-coding-agent}/bin/pi "$@"
            '';
          };
      };
    };
}
