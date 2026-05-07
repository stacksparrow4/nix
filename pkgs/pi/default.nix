{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
}:

pkgs.pi-coding-agent.overrideAttrs rec {
  version = "0.73.1";
  src = pkgs.fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    tag = "v${version}";
    hash = "sha256-ZcqMWghMACzEUswLujwClPF1pbwjTKzTbcYW86ZvjL4=";
  };
  npmDeps = pkgs.fetchNpmDeps {
    name = "pi-mono-${version}-npm-deps";
    inherit src;
    hash = "sha256-tneAcwtTIfkcqQ8/Ch1Xa6OiOkTjJNYbH8wfhNneT/g=";
  };
}
