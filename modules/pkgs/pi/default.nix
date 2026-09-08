{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      pkgsLinux,
      pkgsLinuxUnstable,
      config,
      ...
    }:
    {
      packages.pi =
          let
            buildPi =
              pkgs:
              ((inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
                name = "pi";
                src = ./.;
              }).rootCrate.build;
            pi = buildPi pkgs;
            piLinux = buildPi pkgsLinux;
          in
          pkgs.writeShellApplication {
            name = "pi";
            text = ''
              export SPRRW_PI=${pkgsLinuxUnstable.pi-coding-agent}/bin/pi
              export SPRRW_PI_WRAPPER_LINUX=${piLinux}/bin/pi

              export SPRRW_EXTENSIONS=${./extensions}
              export SPRRW_PROMPTS=${./prompts}

              export PATH="${pkgs.lib.makeBinPath [ config.packages.box ]}:$PATH"

              ${pi}/bin/pi "$@"
            '';
          };
    };
}
