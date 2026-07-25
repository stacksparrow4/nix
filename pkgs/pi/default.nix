{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs-unstable> nixpkgs-inputs,
}:

let
  version = "0.82.0";

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${version}";
    hash = "sha256-oKm0nyGmRY6rlQGMODB8DteMTVUUMroy/YXPphoxrvY=";
  };

  piAiTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-dh4kktq3v1YBFD0AW5+C7JAAM40C0G9ze2V04Ff9YcM=";
  };
in
pkgs.pi-coding-agent.overrideAttrs (
  finalAttrs: prevAttrs: {
    inherit version src;
    npmDeps = pkgs.fetchNpmDeps {
      name = "pi-mono-${version}-npm-deps";
      inherit src;
      hash = "sha256-3oqrN/uguYfkUHlfmKGxnLIvUo484IMGlydz6p9o/Dw=";
    };

    postPatch = (prevAttrs.postPatch or "") + ''
      mkdir -p packages/ai/src/providers/data
      tar -xzf ${piAiTarball} \
        -C packages/ai/src/providers/data \
        --strip-components=4 \
        package/dist/providers/data
    '';

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
