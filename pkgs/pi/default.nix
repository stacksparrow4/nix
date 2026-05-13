{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
}:

let
  version = "0.74.0";

  rawSrc = pkgs.fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    tag = "v${version}";
    hash = "sha256-wEiqOezD8w08vyuenh3Kk+YCYBbQoEq67wATDEKy5XM=";
  };

  # When package-lock.json becomes non malformed this can be removed
  # The below code is really bad practice because its a FOD however
  # it doesn't use a deterministic npm command
  src = pkgs.stdenvNoCC.mkDerivation {
    name = "pi-mono-${version}-src";
    src = rawSrc;
    nativeBuildInputs = [ pkgs.nodejs pkgs.cacert ];
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    dontPatchShebangs = true;
    installPhase = ''
      runHook preInstall
      rm package-lock.json
      export HOME=$TMPDIR
      npm install --package-lock-only --ignore-scripts --force
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-gbapE5o23vBH5tgh6jVLLgAobMuYrbEPw6OqnY2T6JY=";
  };
in
pkgs.pi-coding-agent.overrideAttrs (
  finalAttrs: prevAttrs: {
    inherit version src;
    npmDeps = pkgs.fetchNpmDeps {
      name = "pi-mono-${version}-npm-deps";
      inherit src;
      hash = "sha256-TjkZu/gM153nbvEoh1LditMMZlXjHUM3NTgh0L+5+t0=";
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

# Simple version
# {
#   nixpkgs-inputs ? { },
#   pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
# }:
# 
# pkgs.pi-coding-agent.overrideAttrs rec {
#   version = "0.73.1";
#   src = pkgs.fetchFromGitHub {
#     owner = "badlogic";
#     repo = "pi-mono";
#     tag = "v${version}";
#     hash = "sha256-ZcqMWghMACzEUswLujwClPF1pbwjTKzTbcYW86ZvjL4=";
#   };
#   npmDeps = pkgs.fetchNpmDeps {
#     name = "pi-mono-${version}-npm-deps";
#     inherit src;
#     hash = "sha256-tneAcwtTIfkcqQ8/Ch1Xa6OiOkTjJNYbH8wfhNneT/g=";
#   };
# }
