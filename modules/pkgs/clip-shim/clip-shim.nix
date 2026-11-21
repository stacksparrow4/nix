{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.clip-shim =
        let
          bin =
            (pkgs.callPackage ./_Cargo.nix { }).rootCrate.build;
        in
        pkgs.runCommand "clip-shim" { } ''
          mkdir -p $out/bin $out/shims
          ln -s ${bin}/bin/sprrw-clip $out/bin/sprrw-clip
          ln -s ${bin}/bin/sprrw-clip $out/shims/wl-copy
          ln -s ${bin}/bin/sprrw-clip $out/shims/wl-paste
        '';
    };
}
