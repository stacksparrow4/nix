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
            linuxifyPkgs = pkgs: if pkgs.stdenv.hostPlatform.isLinux then pkgs else import pkgs.path { system = "${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux"; };
            pkgsLinux = linuxifyPkgs pkgs;
            pkgsLinuxUnstable = linuxifyPkgs pkgs-unstable;
            buildPi = pkgs: (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
            pi = buildPi pkgs;
            piLinux = buildPi pkgsLinux;
          in
          pkgs.writeShellApplication {
            name = "pi";
            text = ''
              export SPRRW_PI=${pkgsLinuxUnstable.pi-coding-agent}/bin/pi
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
