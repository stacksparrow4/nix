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
pkgs.pi-coding-agent.overrideAttrs (
  finalAttrs: prevAttrs: {
    inherit version src;
    npmDeps = pkgs.fetchNpmDeps {
      name = "pi-mono-${version}-npm-deps";
      inherit src;
      hash = "sha256-5pHRwxpKg95/phOcYHeWdvPJNtSOhiw7PRoVxsuh0RM=";
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
