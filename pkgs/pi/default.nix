{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
}:

let
  version = "0.80.7";

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${version}";
    hash = "sha256-s7dD82fugvWRvqL1VTcEwCIR5JI6t7VeFHR9NdMtG00=";
  };
in
pkgs.pi-coding-agent.overrideAttrs (
  finalAttrs: prevAttrs: {
    inherit version src;
    npmDeps = pkgs.fetchNpmDeps {
      name = "pi-mono-${version}-npm-deps";
      inherit src;
      hash = "sha256-Bd/NIt3lyQR5Y7P+HksPxMQvJc0AjVfDi1M1bH3/eOg=";
    };

    postInstall = ''
      local nm="$out/lib/node_modules/pi-monorepo/node_modules"

      for ws in @earendil-works/pi-ai:packages/ai \
                @earendil-works/pi-agent-core:packages/agent \
                @earendil-works/pi-tui:packages/tui; do
        IFS=: read -r pkg src <<< "$ws"
        rm "$nm/$pkg"
        cp -r "$src" "$nm/$pkg"
      done

      find "$nm" -type l -lname '*/packages/*' -delete
      find "$nm/.bin" -xtype l -delete
    '';
  }
)
