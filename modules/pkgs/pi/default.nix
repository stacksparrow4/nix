{
  perSystem =
    {
      pkgs,
      pkgs-unstable,
      lib,
      config,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        pi =
          let
            pi = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
          in
          pkgs.writeShellApplication {
            name = "pi";
            text = ''
              export SPRRW_PATH
              if [[ -d /etc/static/hm-package ]] && [[ -d /run/current-system/sw ]]; then
                SPRRW_PATH="$(readlink /etc/static/hm-package)/home-path/bin:$(readlink /run/current-system/sw)/bin"
              fi
              export SPRRW_PI=${pkgs-unstable.pi-coding-agent}/bin/pi 

              export SPRRW_SKILLS=${./skills}
              export SPRRW_EXTENSIONS=${./extensions}
              export SPRRW_PROMPTS=${./prompts}

              export PATH="${config.packages.box}/bin:$PATH"

              ${pi}/bin/pi "$@"
            '';
          };
      };
    };
}
