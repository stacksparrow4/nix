{
  pkgs,
  crane,
  pi,
}:

let
  craneLib = crane.mkLib pkgs;

  commonArgs = {
    src = craneLib.cleanCargoSource ./.;
    strictDeps = true;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  pi-boxed = craneLib.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
    }
  );
in
pkgs.writeShellApplication {
  name = "pi";
  text = ''
    ${pi-boxed}/bin/pi ${pi}/bin/pi "$@"
  '';
}
