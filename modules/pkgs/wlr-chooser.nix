{
  perSystem =
    { pkgs, ... }:
    {
      packages.wlr-chooser = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
        pname = "wlr-chooser";
        version = "v1.11.1";

        src = pkgs.fetchFromGitHub {
          owner = "sjourdois";
          repo = "wlr-utils";
          tag = finalAttrs.version;
          hash = "sha256-AVlZpmUA73UcZjLALHKEz+AhGP6MwqmHgAdamENosTE=";
        };
        cargoHash = "sha256-NaBFMTTlgEkiVtWbHQCuNUmmCPLZc7088AsTwbzSG5o=";
        buildAndTestSubdir = "crates/wlr-chooser";

        buildInputs = with pkgs; [
          wayland
          libxkbcommon
          libgbm
        ];

        nativeBuildInputs = with pkgs; [
          pkg-config
          makeWrapper
        ];

        postFixup = ''
          wrapProgram $out/bin/wlr-chooser --prefix LD_LIBRARY_PATH : ${pkgs.libglvnd}/lib
        '';
      });
    };
}
