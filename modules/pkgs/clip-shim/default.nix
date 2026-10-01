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
        # The derivation exposes both the real binary (bin/sprrw-clip) and a
        # `shims/` directory of tool-named symlinks (wl-copy, wl-paste) that
        # `box --clipboard` prepends to the sandbox PATH. The binary dispatches
        # on its own argv[0], so the symlinks "become" those tools.
        pkgs.runCommand "clip-shim" { } ''
          mkdir -p $out/bin $out/shims
          ln -s ${bin}/bin/sprrw-clip $out/bin/sprrw-clip
          ln -s ${bin}/bin/sprrw-clip $out/shims/wl-copy
          ln -s ${bin}/bin/sprrw-clip $out/shims/wl-paste
        '';
    };
}
