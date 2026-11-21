{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        alternating-layouts = pkgs.stdenv.mkDerivation {
          name = "alternating-layouts";
          propagatedBuildInputs = [
            (pkgs.python313.withPackages (ppkgs: [
              ppkgs.i3ipc
            ]))
          ];
          dontUnpack = true;
          installPhase = "install -Dm755 ${./alternating_layouts.py} $out/bin/alternating-layouts";
        };
      };
    };
}
