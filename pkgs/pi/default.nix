{
  pkgs ? import <nixpkgs-unstable> { },
}:

pkgs.pi-coding-agent.overrideAttrs rec {
  version = "0.73.0";
  src = pkgs.fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    tag = "v${version}";
    hash = "sha256-oE4zMH5KEH185Vdp0CE221sa9rJJw35jFLlfhTa3Sg4=";
  };
  npmDeps = pkgs.fetchNpmDeps {
    name = "pi-mono-${version}-npm-deps";
    inherit src;
    hash = "sha256-rBlAzAnP9aif1tZ984AO4HftIJsDgLQ+02J3td4jcRg=";
  };
}
