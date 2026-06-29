{
  pkgs ? import <nixpkgs-unstable> { },
}:

let
  pi-unsandboxed = import ../pi { inherit pkgs; };
  pi-boxed = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "pi";
    version = "0.1.0";

    src = ./.;

    cargoHash = "sha256-iYxoidXdWkHJnW0bQ1Nwq6TZ6pP40oeKRh7jCDsIzU0=";
  });
in
pkgs.writeShellApplication {
  name = "pi";
  text = ''
    ${pi-boxed}/bin/pi ${pi-unsandboxed}/bin/pi "$@"
  '';
}
