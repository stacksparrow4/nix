{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
}:

let
  version = "0.76.0";

  src = pkgs.fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    tag = "v${version}";
    hash = "sha256-mlnkSmNJbRfDa0DyGvl0hSV1r2aPszW1G6lz5fAqQeY=";
  };

  # Pi version 0.74.0 had a cooked package-lock.json. This can be removed when it is fixed upstream
  # src = pkgs.runCommand "pi-mono-${version}-src" { } ''
  #   cp -r ${rawSrc} $out
  #   chmod -R u+w $out
  #   cp ${./package-lock.json} $out/package-lock.json
  # '';
in
pkgs.pi-coding-agent.overrideAttrs (
  finalAttrs: prevAttrs: {
    inherit version src;
    npmDeps = pkgs.fetchNpmDeps {
      name = "pi-mono-${version}-npm-deps";
      inherit src;
      hash = "sha256-plQH7vJZ7Cxz8Ln0mPFQrmReQYBmhxGmrUlNYm2mtVc=";
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
