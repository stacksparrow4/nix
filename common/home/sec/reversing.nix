{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.reversing.enable = lib.mkEnableOption "reversing";
  };

  config = lib.mkIf config.sprrw.sec.reversing.enable {
    home.packages = with pkgs; [
      binaryninja-free
      ghidra
      radare2

      (
        let
          webcrack = stdenv.mkDerivation (finalAttrs: {
            pname = "webcrack";
            version = "2.15.1";

            src = fetchFromGitHub {
              owner = "j4k0xb";
              repo = "webcrack";
              rev = "32cbd0604af9ba4930f4594cdcfea799d6cf1e81";
              hash = "sha256-1tsVu/uXtX6p+ZhwKiJoa6AoXIBdeK0XcMYcHGaScRU=";
            };

            buildPhase = ''
              (cd packages/webcrack && pnpm run build)
              mv packages/webcrack/dist/cli.js packages/webcrack/dist/webcrack.js
            '';

            installPhase = ''
              mkdir -p "$out/bin"

              cp -r . "$out/src"

              echo '#!${stdenv.shell}' > "$out/bin/webcrack"
              echo "${nodejs}/bin/node '$out/src/packages/webcrack/dist/webcrack.js'"' "$@"' >> "$out/bin/webcrack"
              chmod +x "$out/bin/webcrack"
            '';

            nativeBuildInputs = [
              nodejs
              pnpmConfigHook
              pnpm
            ];

            pnpmDeps = fetchPnpmDeps {
              inherit (finalAttrs) pname version src;
              fetcherVersion = 3;
              hash = "sha256-y/WcTs5zChyGTQaSqzvGwBXPr5TOoLQwmY4Ge/gCW6g=";
            };
          });
        in
          config.sprrw.sandboxing.runDockerBin { binName = "webcrack"; cmd = "${webcrack}/bin/webcrack"; shareCwd = true; }
      )
    ];
  };
}
