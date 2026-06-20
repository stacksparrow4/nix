{
  pkgs ? import <nixpkgs-unstable> { },
}:

pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pi-boxed";
  version = "0.1.0";

  src = ./.;

  cargoHash = "sha256-A6Kbsze8cTzVoqX1jdO0jmW2tBN5qlurhgDS1lX599M=";
})
