{
  pkgs ? import <nixpkgs-unstable> { },
}:

let
  pi-unsandboxed = import ../pi { inherit pkgs; };
  pi-boxed = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "pi";
    version = "0.1.0";

    src = ./.;

    cargoHash = "sha256-+OhzqbPF1slD5SO92WQ1LZYbQ0Hc9qVLlp8d1xnIiSU=";
  });
in
pkgs.writeShellApplication {
  name = "pi";
  text = ''
    ${pi-boxed}/bin/pi ${pi-unsandboxed}/bin/pi "$@"
  '';
}
