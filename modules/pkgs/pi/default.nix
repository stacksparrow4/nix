{
  perSystem =
    {
      pkgs,
      pkgs-linux,
      pkgs-linux-unstable,
      config,
      ...
    }:
    {
      packages.pi =
          let
            buildPi = pkgs: (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
            pi = buildPi pkgs;
            piLinux = buildPi pkgs-linux;
          in
          pkgs.writeShellApplication {
            name = "pi";
            text = ''
              export SPRRW_PI=${pkgs-linux-unstable.pi-coding-agent}/bin/pi
              export SPRRW_PI_WRAPPER_LINUX=${piLinux}/bin/pi

              export SPRRW_SKILLS=${./skills}
              export SPRRW_EXTENSIONS=${./extensions}
              export SPRRW_PROMPTS=${./prompts}

              export PATH="${pkgs.lib.makeBinPath [ config.packages.box ]}:$PATH"

              ${pi}/bin/pi "$@"
            '';
          };
    };
}
