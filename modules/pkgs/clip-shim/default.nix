{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.clip-shim =
        let
          bin =
            (
              (inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
                name = "sprrw-clip";
                src = ./.;
              }
            ).rootCrate.build;
        in
        pkgs.runCommand "clip-shim" { } ''
          mkdir -p $out/bin $out/shims
          ln -s ${bin}/bin/sprrw-clip $out/bin/sprrw-clip
          ln -s ${bin}/bin/sprrw-clip $out/shims/wl-copy
          ln -s ${bin}/bin/sprrw-clip $out/shims/wl-paste
        '';
    };
}
