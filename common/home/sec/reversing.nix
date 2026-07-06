{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.reversing.enable = lib.mkEnableOption "reversing";
  };

  config = lib.mkIf config.sprrw.sec.reversing.enable {
    home.packages = with pkgs; [
      (rizin.withPlugins (plugins: with plugins; [ rz-ghidra ]))

      (
        let
          nodejs = pkgs.nodejs_22;
          webcrack = stdenv.mkDerivation (finalAttrs: {
            pname = "webcrack";
            version = "2.16.0";

            src = pkgs.fetchFromGitHub {
              owner = "j4k0xb";
              repo = "webcrack";
              rev = "f5262d28de8f8ca97b3a3da9681269889b89685f";
              hash = "sha256-DeT89F/eyIF3lXp75gBvZLcFGyO1KzzKTnugZW4X6PU=";
            };

            pnpmDeps = pkgs.fetchPnpmDeps {
              inherit (finalAttrs) pname version src;
              fetcherVersion = 3;
              hash = "sha256-n+lnj5r6LsxN60mG/KhK6oBx8FXVCGTjnGcQU92nAcE=";
            };

            nativeBuildInputs = [
              nodejs
              pkgs.pnpm
              pkgs.pnpmConfigHook
              pkgs.makeWrapper
            ];

            buildPhase = ''
              runHook preBuild
              ( cd packages/webcrack && pnpm run build )
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              # Preserve the full workspace layout so pnpm's relative symlinks
              # (package node_modules -> ../../node_modules/.pnpm/...) keep resolving.
              mkdir -p $out/lib/webcrack
              cp -r . $out/lib/webcrack/

              mkdir -p $out/bin
              makeWrapper ${lib.getExe nodejs} $out/bin/webcrack \
                --add-flags "$out/lib/webcrack/packages/webcrack/dist/cli.js"

              runHook postInstall
            '';
          });
        in
        mkSandbox {
          name = "webcrack";
          shareCwd = true;
          prog = "${webcrack}/bin/webcrack";
        }
      )
    ];
  };
}
