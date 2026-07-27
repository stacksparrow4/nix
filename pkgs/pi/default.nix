{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
}:

let
  version = "0.82.1";

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${version}";
    hash = "sha256-LESpgd/KUoNqdBfnd1oyMN8coKm0Odbo9GYkUDry8Zk=";
  };

  piAiTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-L535UigItiHNNEmHZTfwPYqN+LjX7C1bGMapEKqFtJA=";
  };
in
pkgs.pi-coding-agent.overrideAttrs {
  inherit version src;
  npmDeps = pkgs.fetchNpmDeps {
    name = "pi-mono-${version}-npm-deps";
    inherit src;
    hash = "sha256-5pHRwxpKg95/phOcYHeWdvPJNtSOhiw7PRoVxsuh0RM=";
  };

  modelData = piAiTarball;
}
