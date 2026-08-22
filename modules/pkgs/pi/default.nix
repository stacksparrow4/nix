{
  perSystem =
    {
      pkgs,
      pkgs-unstable,
      config,
      ...
    }:
    {
      packages.pi =
          let
            pi = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
          in
          pkgs.writeShellApplication {
            name = "pi";
            text = ''
              export SPRRW_PI=${pkgs-unstable.pi-coding-agent}/bin/pi 

              export SPRRW_SKILLS=${./skills}
              export SPRRW_EXTENSIONS=${./extensions}
              export SPRRW_PROMPTS=${./prompts}

              export PATH="${pkgs.lib.makeBinPath [ config.packages.box pkgs.nodejs ]}:$PATH"

              ${pi}/bin/pi "$@"
            '';
          };
    };
}
