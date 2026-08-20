{ moduleWithSystem, ... }:

{
  flake.homeModules.programming-rust = moduleWithSystem (
    { pkgs-unstable, ... }:
    { pkgs, ... }:
    let
      # For some reason cargo autocomplete needs rustup to exist
      rustupShim = pkgs.writeShellScriptBin "rustup" "exit 0";

      cargo =
        pkgs.runCommand "cargo-wrapped"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
            inherit (pkgs-unstable.cargo) meta;
          }
          ''
            makeWrapper ${pkgs-unstable.cargo}/bin/cargo $out/bin/cargo \
              --prefix PATH : ${rustupShim}/bin

            mkdir -p $out/share/bash-completion/completions
            sed -E 's#"/nix/store/[^"]*/bin/cargo"#"'"$out"'/bin/cargo"#' \
              ${pkgs-unstable.cargo}/share/bash-completion/completions/cargo.bash \
              > $out/share/bash-completion/completions/cargo.bash
          '';
    in
    {
      home.packages = [
        cargo
        pkgs-unstable.rustc
        pkgs-unstable.rustfmt
        pkgs.crate2nix
      ];
    }
  );
}
