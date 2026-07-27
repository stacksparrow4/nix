{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

let
  craneLib = crane.mkLib pkgs;

  pi-unsandboxed = import ../pi { inherit pkgs; };

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
    ${pi-boxed}/bin/pi ${pi-unsandboxed}/bin/pi "$@"
  '';
}
