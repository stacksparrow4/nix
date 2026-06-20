{
  pkgs ? import <nixpkgs-unstable> { },
}:

pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pi-boxed";
  version = "0.1.0";

  src = ./.;

  cargoHash = "sha256-DSAts9YU047FobitsDcHvbQ9cy00n/DTedZmduRRxEs=";
})
